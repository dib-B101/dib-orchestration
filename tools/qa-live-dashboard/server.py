#!/usr/bin/env python3
"""DIB production-like EKS logs rendered as a local, read-only QA dashboard."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
import webbrowser
from collections import deque
from datetime import datetime, timezone
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parent
STATIC_ROOT = ROOT / "static"
STOP = threading.Event()
LOCK = threading.RLock()
EVENTS: deque[dict[str, Any]] = deque(maxlen=240)
CHILDREN: list[subprocess.Popen[str]] = []
EVENT_SEQUENCE = 0
STATE: dict[str, Any] = {
    "connected": False,
    "context": "확인 중",
    "updatedAt": None,
    "pods": [],
    "hpa": {},
    "kafka": {"lag": None, "groups": [], "ok": False},
    "websocket": {"current": 0, "total": 0, "transportErrors": 0},
    "errors": [],
}

POD_PREFIX = re.compile(r"^\[pod/(?P<pod>[^/]+)/(?P<container>[^]]+)]\s*(?P<body>.*)$")
SPRING_LINE = re.compile(
    r"^(?P<timestamp>\d{4}-\d{2}-\d{2}T\S+)\s+"
    r"(?P<level>INFO|WARN|ERROR|DEBUG)\s+\d+\s+---\s+.*?\s:\s(?P<message>.*)$"
)
WS_STATS = re.compile(
    r"WebSocketSession\[(?P<current>\d+) current .*?, (?P<total>\d+) total, .*?"
    r"(?P<errors>\d+) transport error"
)
TRACE_PAIR = re.compile(r"(?P<key>[A-Za-z][A-Za-z0-9]*)=(?P<value>[^\s]+)")
SENSITIVE_PATTERNS = (
    (re.compile(r"(?i)(authorization|accessToken|refreshToken|password|secret)=\S+"), r"\1=***"),
    (re.compile(r"(?i)Bearer\s+[A-Za-z0-9._~+\-/]+=*"), "Bearer ***"),
    (re.compile(r"\b010[- ]?\d{3,4}[- ]?\d{4}\b"), "010-****-****"),
    (re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"), "***@***"),
)
NOISE = (
    "ConsumerCoordinator",
    "KafkaMessageListenerContainer",
    "ConsumerUtils",
    "WebSocketMessageBrokerStats",
    "HikariPool",
    "Tomcat",
    "Flyway",
)


def creation_flags() -> int:
    return subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def kubectl(*args: str, timeout: int = 15) -> str:
    completed = subprocess.run(
        ["kubectl", *args],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        check=False,
        creationflags=creation_flags(),
    )
    if completed.returncode:
        message = completed.stderr.strip() or completed.stdout.strip()
        raise RuntimeError(message or f"kubectl exit={completed.returncode}")
    return completed.stdout


def redact(value: str) -> str:
    result = value
    for pattern, replacement in SENSITIVE_PATTERNS:
        result = pattern.sub(replacement, result)
    return result


def local_time(timestamp: str | None = None) -> str:
    if timestamp:
        try:
            parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            return parsed.astimezone().strftime("%H:%M:%S")
        except ValueError:
            pass
    return datetime.now().strftime("%H:%M:%S")


def pod_display_name(pod_name: str) -> str:
    with LOCK:
        backends = sorted(p["name"] for p in STATE["pods"] if p.get("role") == "backend")
    if pod_name in backends:
        return f"backend-{chr(ord('A') + backends.index(pod_name))}"
    if pod_name.startswith("dib-ai"):
        return "dib-ai"
    if pod_name.startswith("kafka"):
        return "kafka"
    return pod_name.rsplit("-", 1)[-1]


def pod_zone(pod_name: str) -> str:
    with LOCK:
        for pod in STATE["pods"]:
            if pod.get("name") == pod_name:
                return pod.get("zone", "-")
        role_alias = {"dib-ai": "ai", "kafka": "kafka"}.get(pod_name)
        if role_alias:
            for pod in STATE["pods"]:
                if pod.get("role") == role_alias:
                    return pod.get("zone", "-")
    return "-"


def add_event(
    category: str,
    title: str,
    detail: str = "",
    *,
    pod: str = "system",
    level: str = "INFO",
    timestamp: str | None = None,
    request_id: str | None = None,
    stage: str | None = None,
    duration_ms: str | None = None,
) -> None:
    global EVENT_SEQUENCE
    title = redact(title.strip())
    detail = redact(detail.strip())
    fingerprint = (category, title, detail, pod)
    with LOCK:
        if EVENTS and EVENTS[-1].get("fingerprint") == fingerprint:
            if time.time() - EVENTS[-1]["epoch"] < 1.5:
                return
        EVENT_SEQUENCE += 1
        EVENTS.append(
            {
                "id": EVENT_SEQUENCE,
                "time": local_time(timestamp),
                "epoch": time.time(),
                "category": category,
                "title": title,
                "detail": detail,
                "pod": pod_display_name(pod),
                "podRaw": pod,
                "zone": pod_zone(pod),
                "level": level,
                "requestId": request_id,
                "stage": stage,
                "durationMs": duration_ms,
                "fingerprint": fingerprint,
            }
        )


def parse_structured_trace(message: str, pod: str, level: str, timestamp: str | None) -> bool:
    if "[DIB-TRACE]" not in message:
        return False
    fields = {match.group("key"): match.group("value") for match in TRACE_PAIR.finditer(message)}
    stage = fields.get("stage", "TRACE")
    stage_labels = {
        "HTTP": "HTTP 요청 수신",
        "REDIS_LOCK": "Redis 분산락 획득",
        "DB": "PostgreSQL 커밋",
        "CACHE": "Redis Snapshot 갱신",
        "PUBSUB": "Redis Pub/Sub 전파",
        "WS": "WebSocket 전송",
        "OUTBOX": "Outbox 이벤트 생성",
        "KAFKA": "Kafka Consumer 처리",
        "AI_REQUESTED": "AI 검수 요청",
        "AI_RESULT": "AI 검수 결과 반영",
    }
    category = "ai" if stage.startswith("AI") else "auction"
    detail_parts = []
    for key in ("auctionId", "productId", "event", "result"):
        if key in fields:
            detail_parts.append(f"{key}={fields[key]}")
    add_event(
        category,
        stage_labels.get(stage, stage),
        " · ".join(detail_parts),
        pod=pod,
        level=level,
        timestamp=timestamp,
        request_id=fields.get("requestId"),
        stage=stage,
        duration_ms=fields.get("durationMs"),
    )
    return True


def normalized_business_event(message: str) -> tuple[str, str, str] | None:
    match = re.search(r"상품 검수 반영 productId=(\d+) status=(\w+) stage=(\w+)", message)
    if match:
        status = match.group(2)
        title = "상품 검수 거절" if status == "REJECTED" else "상품 검수 통과"
        return "ai", title, f"상품 #{match.group(1)} · {status} · {match.group(3)}"

    match = re.search(r"AI 추천 요청 memberId=(\d+) jobId=(\S+) accepted=(\w+)", message)
    if match:
        return "ai", "AI 추천 요청", f"회원 #{match.group(1)} · accepted={match.group(3)}"

    match = re.search(r"경매 종료 auctionId=(\d+) result=(\w+) orderId=(\S+)", message)
    if match:
        return "auction", "경매 종료", f"경매 #{match.group(1)} · {match.group(2)} · 주문 {match.group(3)}"

    match = re.search(r"이상입찰 분석 요청 auctionId=(\d+) (\d+)건", message)
    if match:
        return "security", "이상입찰 분석 요청", f"경매 #{match.group(1)} · 분석 {match.group(2)}건"

    match = re.search(r"낙찰 자동결제 실패 orderId=(\d+) code=(\S+)", message)
    if match:
        return "payment", "자동결제 확인 필요", f"주문 #{match.group(1)} · {match.group(2)}"

    if "outbox 발행" in message:
        return "kafka", "Outbox 이벤트", message
    if "Redis 락" in message:
        return "redis", "Redis 분산락", message
    if "스냅샷" in message:
        return "redis", "Redis Snapshot", message
    if "realtime 메시지" in message or "Redis 발행" in message:
        return "websocket", "실시간 메시지", message
    if any(word in message for word in ("결제", "정산", "주문")):
        return "payment", "결제·거래 이벤트", message
    if any(word in message for word in ("신고", "제재", "이상입찰")):
        return "security", "관리·보안 이벤트", message
    if any(word in message for word in ("입찰", "경매")):
        return "auction", "경매 이벤트", message
    if any(word in message for word in ("검수", "AI ")):
        return "ai", "AI 이벤트", message
    return None


def parse_backend_line(raw: str) -> None:
    line = raw.strip()
    if not line:
        return
    prefix = POD_PREFIX.match(line)
    pod = prefix.group("pod") if prefix else "dib-backend"
    body = prefix.group("body") if prefix else line
    spring = SPRING_LINE.match(body)
    timestamp = spring.group("timestamp") if spring else None
    level = spring.group("level") if spring else "INFO"
    message = spring.group("message") if spring else body

    stats = WS_STATS.search(message)
    if stats:
        with LOCK:
            STATE["websocket"] = {
                "current": int(stats.group("current")),
                "total": int(stats.group("total")),
                "transportErrors": int(stats.group("errors")),
            }
        return
    if parse_structured_trace(message, pod, level, timestamp):
        return
    event = normalized_business_event(message)
    if event:
        add_event(event[0], event[1], event[2], pod=pod, level=level, timestamp=timestamp)
        return
    if level in ("WARN", "ERROR") and not any(noise in body for noise in NOISE):
        add_event("alert", "백엔드 경고" if level == "WARN" else "백엔드 오류", message, pod=pod, level=level, timestamp=timestamp)


def parse_ai_line(raw: str) -> None:
    line = raw.strip()
    if not line or '"GET /health ' in line:
        return
    if "POST /internal/moderation/review" in line:
        status = re.search(r'HTTP/1\.1"\s+(\d+)', line)
        add_event("ai", "AI 이미지·텍스트 검수 처리", f"HTTP {status.group(1) if status else '-'}", pod="dib-ai")
        return
    if "POST /internal/v1/ai/recommendations" in line:
        status = re.search(r'HTTP/1\.1"\s+(\d+)', line)
        add_event("ai", "AI 추천 생성 요청", f"HTTP {status.group(1) if status else '-'}", pod="dib-ai")
        return
    if "임베딩 조회 실패" in line or "UndefinedColumn" in line:
        add_event("alert", "AI 추천 DB 스키마 오류", "text_embedding 컬럼을 확인해야 합니다", pod="dib-ai", level="ERROR")
        return
    if line.startswith(("Traceback", "File ", "LINE ", "^")):
        return
    if "ERROR" in line or "Exception" in line:
        add_event("alert", "AI 서버 오류", line[:240], pod="dib-ai", level="ERROR")


def stream_logs(selector_args: list[str], parser) -> None:
    while not STOP.is_set():
        command = ["kubectl", "logs", "-f", *selector_args, "--tail=0"]
        process: subprocess.Popen[str] | None = None
        try:
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
                creationflags=creation_flags(),
            )
            CHILDREN.append(process)
            assert process.stdout is not None
            for line in process.stdout:
                if STOP.is_set():
                    break
                parser(line)
        except Exception as exc:  # noqa: BLE001 - dashboard must stay alive
            add_event("alert", "로그 스트림 재연결", str(exc), level="WARN")
        finally:
            if process and process.poll() is None:
                process.terminate()
            if process in CHILDREN:
                CHILDREN.remove(process)
        STOP.wait(2)


def parse_cpu(value: str) -> int:
    if value.endswith("n"):
        return round(int(value[:-1]) / 1_000_000)
    if value.endswith("u"):
        return round(int(value[:-1]) / 1_000)
    if value.endswith("m"):
        return int(value[:-1])
    return int(float(value) * 1000)


def parse_memory(value: str) -> int:
    units = {"Ki": 1 / 1024, "Mi": 1, "Gi": 1024}
    for suffix, multiplier in units.items():
        if value.endswith(suffix):
            return round(float(value[: -len(suffix)]) * multiplier)
    return round(int(value) / 1024 / 1024)


def status_loop(namespace: str) -> None:
    while not STOP.is_set():
        try:
            nodes = json.loads(kubectl("get", "nodes", "-o", "json"))
            node_zones = {
                item["metadata"]["name"]: item["metadata"].get("labels", {}).get("topology.kubernetes.io/zone", "-")
                for item in nodes.get("items", [])
            }
            pods_result = json.loads(kubectl("get", "pods", "-n", namespace, "-o", "json"))
            try:
                metrics_result = json.loads(kubectl("get", "--raw", f"/apis/metrics.k8s.io/v1beta1/namespaces/{namespace}/pods"))
            except Exception:
                metrics_result = {"items": []}
            metrics: dict[str, tuple[int, int]] = {}
            for item in metrics_result.get("items", []):
                cpu = sum(parse_cpu(c["usage"]["cpu"]) for c in item.get("containers", []))
                memory = sum(parse_memory(c["usage"]["memory"]) for c in item.get("containers", []))
                metrics[item["metadata"]["name"]] = (cpu, memory)

            pods = []
            for item in pods_result.get("items", []):
                name = item["metadata"]["name"]
                labels = item["metadata"].get("labels", {})
                app = labels.get("app", "")
                if app not in ("dib-backend", "dib-ai", "dib-admin-web", "kafka"):
                    continue
                role = {
                    "dib-backend": "backend",
                    "dib-ai": "ai",
                    "dib-admin-web": "admin",
                    "kafka": "kafka",
                }[app]
                statuses = item.get("status", {}).get("containerStatuses", [])
                ready = bool(statuses) and all(status.get("ready") for status in statuses)
                restarts = sum(status.get("restartCount", 0) for status in statuses)
                cpu, memory = metrics.get(name, (0, 0))
                node = item.get("spec", {}).get("nodeName", "-")
                images = [container.get("image", "") for container in item.get("spec", {}).get("containers", [])]
                pods.append(
                    {
                        "name": name,
                        "role": role,
                        "ready": ready,
                        "phase": item.get("status", {}).get("phase", "Unknown"),
                        "restarts": restarts,
                        "node": node,
                        "zone": node_zones.get(node, "-"),
                        "ip": item.get("status", {}).get("podIP", "-"),
                        "cpuMillicores": cpu,
                        "memoryMi": memory,
                        "image": images[0] if images else "-",
                    }
                )

            hpa_result = json.loads(kubectl("get", "hpa", "dib-backend", "-n", namespace, "-o", "json"))
            metric = (hpa_result.get("status", {}).get("currentMetrics") or [{}])[0]
            resource = metric.get("resource", {})
            hpa = {
                "currentReplicas": hpa_result.get("status", {}).get("currentReplicas", 0),
                "desiredReplicas": hpa_result.get("status", {}).get("desiredReplicas", 0),
                "minReplicas": hpa_result.get("spec", {}).get("minReplicas", 0),
                "maxReplicas": hpa_result.get("spec", {}).get("maxReplicas", 0),
                "cpuPercent": resource.get("current", {}).get("averageUtilization"),
                "targetCpuPercent": resource.get("target", {}).get("averageUtilization"),
            }
            context = kubectl("config", "current-context").strip()
            with LOCK:
                STATE.update(
                    {
                        "connected": True,
                        "context": context,
                        "updatedAt": datetime.now().isoformat(),
                        "pods": sorted(pods, key=lambda pod: (pod["role"], pod["name"])),
                        "hpa": hpa,
                    }
                )
        except Exception as exc:  # noqa: BLE001
            with LOCK:
                STATE["connected"] = False
                STATE["errors"] = [redact(str(exc))[:300]]
        STOP.wait(3)


def kafka_loop(namespace: str) -> None:
    command = "/opt/kafka/bin/kafka-consumer-groups.sh"
    while not STOP.is_set():
        try:
            output = kubectl(
                "exec",
                "kafka-0",
                "-n",
                namespace,
                "--",
                command,
                "--bootstrap-server",
                "localhost:9092",
                "--all-groups",
                "--describe",
                timeout=25,
            )
            aggregate: dict[tuple[str, str], dict[str, Any]] = {}
            for line in output.splitlines():
                parts = line.split()
                if len(parts) < 6 or parts[0] == "GROUP":
                    continue
                try:
                    lag = int(parts[5])
                except ValueError:
                    continue
                key = (parts[0], parts[1])
                current = aggregate.setdefault(key, {"group": parts[0], "topic": parts[1], "lag": 0, "partitions": 0})
                current["lag"] += lag
                current["partitions"] += 1
            groups = sorted(aggregate.values(), key=lambda item: (item["group"], item["topic"]))
            with LOCK:
                STATE["kafka"] = {
                    "lag": sum(item["lag"] for item in groups),
                    "groups": groups,
                    "ok": True,
                    "updatedAt": datetime.now().isoformat(),
                }
        except Exception as exc:  # noqa: BLE001
            with LOCK:
                STATE["kafka"] = {"lag": None, "groups": [], "ok": False, "error": redact(str(exc))[:200]}
        STOP.wait(8)


class DashboardHandler(BaseHTTPRequestHandler):
    server_version = "DIBLiveTrace/1.0"

    def log_message(self, _format: str, *_args: Any) -> None:
        return

    def send_bytes(self, content: bytes, content_type: str, status: int = 200) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self) -> None:  # noqa: N802
        path = urlparse(self.path).path
        if path == "/api/snapshot":
            with LOCK:
                state = json.loads(json.dumps(STATE))
                events = [{key: value for key, value in event.items() if key != "fingerprint"} for event in EVENTS]
            body = json.dumps({"state": state, "events": events}, ensure_ascii=False).encode("utf-8")
            self.send_bytes(body, "application/json; charset=utf-8")
            return
        if path in ("/", "/index.html"):
            self.send_bytes((STATIC_ROOT / "index.html").read_bytes(), "text/html; charset=utf-8")
            return
        self.send_bytes(b"Not found", "text/plain; charset=utf-8", HTTPStatus.NOT_FOUND)

    def do_POST(self) -> None:  # noqa: N802
        if urlparse(self.path).path == "/api/events/clear":
            with LOCK:
                EVENTS.clear()
            self.send_bytes(b'{"ok":true}', "application/json; charset=utf-8")
            return
        self.send_bytes(b"Not found", "text/plain; charset=utf-8", HTTPStatus.NOT_FOUND)


class DashboardServer(ThreadingHTTPServer):
    allow_reuse_address = False


def start_thread(target, *args) -> None:
    threading.Thread(target=target, args=args, daemon=True).start()


def main() -> int:
    parser = argparse.ArgumentParser(description="DIB EKS live QA dashboard")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--namespace", default="default")
    parser.add_argument("--no-browser", action="store_true")
    args = parser.parse_args()

    if not shutil_which("kubectl"):
        print("kubectl was not found.", file=sys.stderr)
        return 1
    try:
        context = kubectl("config", "current-context").strip()
        kubectl("get", "deployment", "dib-backend", "-n", args.namespace, "-o", "name")
    except Exception as exc:  # noqa: BLE001
        print(f"Kubernetes connection failed: {exc}", file=sys.stderr)
        return 1

    with LOCK:
        STATE["context"] = context
    add_event("system", "실제 EKS 연결", context, pod="system")
    start_thread(status_loop, args.namespace)
    start_thread(kafka_loop, args.namespace)
    start_thread(
        stream_logs,
        ["-n", args.namespace, "-l", "app=dib-backend", "--all-containers=true", "--prefix=true"],
        parse_backend_line,
    )
    start_thread(stream_logs, ["-n", args.namespace, "deployment/dib-ai"], parse_ai_line)

    url = f"http://127.0.0.1:{args.port}"
    try:
        server = DashboardServer(("127.0.0.1", args.port), DashboardHandler)
    except OSError as exc:
        print(f"Dashboard port is already in use: {url} ({exc})", file=sys.stderr)
        if not args.no_browser:
            webbrowser.open(url)
        STOP.set()
        for process in list(CHILDREN):
            if process.poll() is None:
                process.terminate()
        return 1
    print(f"DIB Live Trace: {url}")
    print("Read-only EKS observer. Press Ctrl+C to stop.")
    if not args.no_browser:
        threading.Timer(1.0, lambda: webbrowser.open(url)).start()
    try:
        server.serve_forever(poll_interval=0.5)
    except KeyboardInterrupt:
        pass
    finally:
        STOP.set()
        server.server_close()
        for process in list(CHILDREN):
            if process.poll() is None:
                process.terminate()
    return 0


def shutil_which(command: str) -> str | None:
    from shutil import which

    return which(command)


if __name__ == "__main__":
    raise SystemExit(main())
