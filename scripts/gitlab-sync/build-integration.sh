#!/usr/bin/env bash

set -euo pipefail

: "${TARGET_BRANCH:?TARGET_BRANCH is required}"
: "${GITLAB_MIRROR_USERNAME:?GITLAB_MIRROR_USERNAME is required}"
: "${GITLAB_MIRROR_TOKEN:?GITLAB_MIRROR_TOKEN is required}"

if [[ "${TARGET_BRANCH}" != "main" && "${TARGET_BRANCH}" != "develop" ]]; then
  echo "TARGET_BRANCH must be main or develop." >&2
  exit 1
fi

orchestration_dir="${ORCHESTRATION_DIR:-${GITHUB_WORKSPACE:-$(pwd)}}"
gitlab_url="${GITLAB_MIRROR_URL:-https://lab.ssafy.com/s15-bigdata-recom-sub1/S15P21B101.git}"

component_names=(frontend backend ai infra)
component_paths=(
  components/frontend
  components/backend
  components/ai
  components/infra
)
component_repositories=(
  dib-B101/dib-frontend
  dib-B101/dib-backend
  dib-B101/dib-ai
  dib-B101/dib-infra
)

temp_dir="$(mktemp -d)"
trap 'rm -rf -- "${temp_dir}"' EXIT

askpass_script="${temp_dir}/git-askpass.sh"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'case "$1" in' \
  '  *Username*) printf "%s\n" "${GITLAB_MIRROR_USERNAME}" ;;' \
  '  *Password*) printf "%s\n" "${GITLAB_MIRROR_TOKEN}" ;;' \
  '  *) exit 1 ;;' \
  'esac' >"${askpass_script}"
chmod 700 "${askpass_script}"

export GIT_ASKPASS="${askpass_script}"
export GIT_TERMINAL_PROMPT=0
export GITLAB_MIRROR_USERNAME
export GITLAB_MIRROR_TOKEN

orchestration_sha="$(git -C "${orchestration_dir}" rev-parse HEAD)"
checked_out_branch="$(git -C "${orchestration_dir}" branch --show-current)"
if [[ -n "${checked_out_branch}" && "${checked_out_branch}" != "${TARGET_BRANCH}" ]]; then
  echo "Expected ${TARGET_BRANCH}, but orchestration checkout is ${checked_out_branch}." >&2
  exit 1
fi

snapshot_dir="${temp_dir}/snapshot"
mkdir -p "${snapshot_dir}"
git -C "${orchestration_dir}" archive HEAD | tar -xf - -C "${snapshot_dir}"
rm -f -- "${snapshot_dir}/.gitmodules"

component_shas=()
for index in "${!component_names[@]}"; do
  component_path="${component_paths[$index]}"
  source_path="${orchestration_dir}/${component_path}"

  if [[ ! -d "${source_path}" ]]; then
    echo "Submodule directory is missing: ${component_path}" >&2
    exit 1
  fi

  expected_sha="$(git -C "${orchestration_dir}" ls-tree HEAD "${component_path}" | awk '{print $3}')"
  actual_sha="$(git -C "${source_path}" rev-parse HEAD)"
  if [[ -z "${expected_sha}" || "${expected_sha}" != "${actual_sha}" ]]; then
    echo "Submodule SHA mismatch for ${component_path}: expected ${expected_sha}, got ${actual_sha}" >&2
    exit 1
  fi

  component_shas+=("${actual_sha}")
  destination_path="${snapshot_dir}/${component_path}"
  mkdir -p "${destination_path}"
  git -C "${source_path}" archive HEAD | tar -xf - -C "${destination_path}"
done

mkdir -p "${snapshot_dir}/.sync"
lock_file="${snapshot_dir}/.sync/components.lock"
{
  printf 'schema: 1\n'
  printf 'branch: %s\n' "${TARGET_BRANCH}"
  printf 'repositories:\n'
  printf '  orchestration:\n'
  printf '    repository: dib-B101/dib-orchestration\n'
  printf '    commit: %s\n' "${orchestration_sha}"
  for index in "${!component_names[@]}"; do
    printf '  %s:\n' "${component_names[$index]}"
    printf '    repository: %s\n' "${component_repositories[$index]}"
    printf '    commit: %s\n' "${component_shas[$index]}"
  done
} >"${lock_file}"

integrated_dir="${temp_dir}/integrated"
git init --quiet "${integrated_dir}"
git -C "${integrated_dir}" config core.autocrlf false
git -C "${integrated_dir}" remote add gitlab "${gitlab_url}"

set +e
git ls-remote --exit-code --heads "${gitlab_url}" "refs/heads/${TARGET_BRANCH}" >/dev/null
remote_branch_status=$?
set -e

case "${remote_branch_status}" in
  0)
    git -C "${integrated_dir}" fetch --quiet gitlab \
      "refs/heads/${TARGET_BRANCH}:refs/remotes/gitlab/${TARGET_BRANCH}"
    git -C "${integrated_dir}" checkout --quiet -b "${TARGET_BRANCH}" \
      "refs/remotes/gitlab/${TARGET_BRANCH}"
    git -C "${integrated_dir}" rm -r --quiet --ignore-unmatch .
    ;;
  2)
    git -C "${integrated_dir}" checkout --quiet --orphan "${TARGET_BRANCH}"
    ;;
  *)
    echo "Unable to inspect GitLab branch ${TARGET_BRANCH}." >&2
    exit "${remote_branch_status}"
    ;;
esac

tar -cf - -C "${snapshot_dir}" . | tar -xf - -C "${integrated_dir}"
git -C "${integrated_dir}" add --all

if git -C "${integrated_dir}" diff --cached --quiet; then
  echo "Integrated ${TARGET_BRANCH} is already up to date."
  exit 0
fi

author_name="$(git -C "${orchestration_dir}" log -1 --format=%an)"
author_email="$(git -C "${orchestration_dir}" log -1 --format=%ae)"
author_date="$(git -C "${orchestration_dir}" log -1 --format=%aI)"
short_sha="$(git -C "${orchestration_dir}" rev-parse --short=12 HEAD)"

GIT_AUTHOR_NAME="${author_name}" \
GIT_AUTHOR_EMAIL="${author_email}" \
GIT_AUTHOR_DATE="${author_date}" \
GIT_COMMITTER_NAME="DIB Integration Sync" \
GIT_COMMITTER_EMAIL="sync@dib.invalid" \
GIT_COMMITTER_DATE="${author_date}" \
  git -C "${integrated_dir}" commit --quiet \
    -m "sync(${TARGET_BRANCH}): orchestration ${short_sha} 통합"

git -C "${integrated_dir}" push --porcelain gitlab \
  "HEAD:refs/heads/${TARGET_BRANCH}"
