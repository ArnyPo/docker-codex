#!/bin/bash
set -e

# docker run flags:
#   OPENAI_API_KEY — forwarded when set on the host (optional alternative to sign-in)
#   GITHUB_PAT — forwarded for authenticated first-run GitHub R package installs
#   USER_ID/GROUP_ID — preserve file ownership
#   --group-add 1001 — grants lab group access
#   --security-opt seccomp=unconfined — lets Bubblewrap create namespaces
#   $(pwd) expanded at call time because of single quotes
#   mount and workdir use the literal host path so container paths match host paths
#   optional first absolute-directory argument — second host path, mounted read-write
#   remaining arguments are passed to the Codex executable (for example: codex --help)

# Persist the function directly in ~/.bashrc
mkdir -p "$HOME/codex/codex-home"
TMPFILE=$(mktemp)
cat > "$TMPFILE" << 'EOF'
# BEGIN codex alias
codex() {
  local extra_mount=() extra_env=() codex_args=()
  if [ "$#" -gt 0 ] && [[ "$1" = /* ]] && [ -d "$1" ]; then
    extra_mount=(-v "$1:$1")
    extra_env=(-e SECONDARY_WORKSPACE="$1")
    shift
  fi
  codex_args=("$@")
  # Docker arguments after the image replace its CMD, so explicitly retain
  # the executable before forwarding user-supplied Codex arguments.
  docker run -it --rm \
    --env OPENAI_API_KEY \
    --env GITHUB_PAT \
    -e USER_ID="$(id -u)" \
    -e GROUP_ID="$(id -g)" \
    --group-add 1001 \
    --security-opt seccomp=unconfined \
    --security-opt apparmor=unconfined \
    --cap-add SYS_ADMIN \
    -v "$(pwd):$(pwd)" \
    -w "$(pwd)" \
    -v "$HOME/codex/codex-home:/home/codex" \
    "${extra_mount[@]}" \
    "${extra_env[@]}" \
    codex-main \
    codex \
    "${codex_args[@]}"
}
# END codex alias
EOF

python3 - "$TMPFILE" << 'PYEOF'
import sys, os, re
new_block = open(sys.argv[1]).read().strip()
bashrc_path = os.path.expanduser('~/.bashrc')
content = open(bashrc_path).read() if os.path.exists(bashrc_path) else ''
pattern = r'# BEGIN (?:claude-code|codex) alias.*?# END (?:claude-code|codex) alias'
if re.search(pattern, content, re.DOTALL):
    content = re.sub(pattern, new_block, content, flags=re.DOTALL)
else:
    content = content.rstrip('\n') + '\n\n' + new_block + '\n'
open(bashrc_path, 'w').write(content)
PYEOF

rm "$TMPFILE"
