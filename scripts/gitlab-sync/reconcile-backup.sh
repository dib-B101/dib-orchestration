#!/usr/bin/env bash

set -euo pipefail

: "${NAMESPACE:?NAMESPACE is required}"
: "${GITLAB_MIRROR_USERNAME:?GITLAB_MIRROR_USERNAME is required}"
: "${GITLAB_MIRROR_TOKEN:?GITLAB_MIRROR_TOKEN is required}"

if [[ ! "${NAMESPACE}" =~ ^(orch|fe|be|ai|infra)$ ]]; then
  echo "Unsupported namespace: ${NAMESPACE}" >&2
  exit 1
fi

gitlab_url="${GITLAB_MIRROR_URL:-https://lab.ssafy.com/s15-bigdata-recom-sub1/S15P21B101.git}"

if [[ -n "${SOURCE_REPOSITORY_URL:-}" ]]; then
  source_url="${SOURCE_REPOSITORY_URL}"
else
  : "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required when SOURCE_REPOSITORY_URL is not set}"
  source_url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}.git"
fi

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

mirror_dir="${temp_dir}/source.git"
git init --bare --quiet "${mirror_dir}"
git -C "${mirror_dir}" fetch --quiet --force --prune "${source_url}" \
  '+refs/heads/*:refs/heads/*' \
  '+refs/tags/*:refs/tags/*'

if ! git -C "${mirror_dir}" show-ref --verify --quiet refs/heads/main; then
  echo "Source repository does not contain refs/heads/main; refusing to prune the backup namespace." >&2
  exit 1
fi

git -C "${mirror_dir}" push --porcelain --force --prune "${gitlab_url}" \
  "+refs/heads/*:refs/heads/${NAMESPACE}/*" \
  "+refs/tags/*:refs/tags/${NAMESPACE}/*"

