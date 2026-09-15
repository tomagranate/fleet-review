#!/usr/bin/env bash
# Drop leftover jbot containers and root-owned files from a previous run.
# Never fail the job: a cleanup miss is better than blocking review.
set +e

image="ghcr.io/pgup-ai/jbot-review:latest-slim"
workspace="${GITHUB_WORKSPACE:-}"
runner_temp="${RUNNER_TEMP:-}"
runner_workspace="${RUNNER_WORKSPACE:-}"

owns_this_job() {
  local cid="$1" src
  while IFS= read -r src; do
    [[ -n "$src" ]] || continue
    if [[ -n "$workspace" && "$src" == "$workspace" ]]; then
      return 0
    fi
    if [[ -n "$runner_workspace" && "$src" == "$runner_workspace" ]]; then
      return 0
    fi
    if [[ -n "$runner_workspace" && "$src" == "$runner_workspace"/* ]]; then
      return 0
    fi
    if [[ -n "$runner_temp" && "$src" == "$runner_temp" ]]; then
      return 0
    fi
    if [[ -n "$runner_temp" && "$src" == "$runner_temp"/* ]]; then
      return 0
    fi
  done < <(docker inspect -f '{{range .Mounts}}{{.Source}}{{"\n"}}{{end}}' "$cid" 2>/dev/null)
  return 1
}

if command -v docker >/dev/null 2>&1; then
  while IFS= read -r cid; do
    [[ -n "$cid" ]] || continue
    if owns_this_job "$cid"; then
      docker rm -f "$cid" >/dev/null 2>&1
    fi
  done < <(docker ps -aq --filter "ancestor=$image" 2>/dev/null)
fi

docker_root_rm() {
  local host_dir="$1" guest_path="$2"
  [[ -n "$host_dir" && -d "$host_dir" ]] || return 0
  command -v docker >/dev/null 2>&1 || return 0
  docker run --rm --user 0:0 --entrypoint /bin/rm \
    -v "$host_dir:/mnt" \
    "$image" \
    -rf "$guest_path" >/dev/null 2>&1
}

if [[ -n "$workspace" ]]; then
  rm -rf "${workspace}/.jbot-review" 2>/dev/null
  docker_root_rm "$workspace" /mnt/.jbot-review
fi

if [[ -n "$runner_temp" ]]; then
  rm -rf "${runner_temp}/jbot-shard-cache" 2>/dev/null
  docker_root_rm "$runner_temp" /mnt/jbot-shard-cache
  chmod a+rwX "$runner_temp" 2>/dev/null
  if [[ -d "${runner_temp}/_runner_file_commands" ]]; then
    chmod a+rwX "${runner_temp}/_runner_file_commands" 2>/dev/null
    chmod a+rw "${runner_temp}/_runner_file_commands/"* 2>/dev/null
    if [[ ! -w "${runner_temp}/_runner_file_commands" ]] && command -v docker >/dev/null 2>&1; then
      docker run --rm --user 0:0 --entrypoint /bin/chmod \
        -v "$runner_temp:/mnt" \
        "$image" \
        -R a+rwX /mnt/_runner_file_commands >/dev/null 2>&1
    fi
  fi
fi

exit 0
