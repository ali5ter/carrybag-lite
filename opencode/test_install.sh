#!/usr/bin/env bash
#
# test_install.sh - Sandboxed end-to-end tests for install.sh
#
# Runs a throwaway copy of the opencode/ directory against a stub model server
# on localhost, with HOME pointed at an empty sandbox, and checks:
#
#   1. a fresh install writes the 131072 / 32768 defaults
#   2. a hand-edited limit.context survives a rerun (the silent-reset trap,
#      Issue #92)
#   3. an explicit OPENCODE_CONTEXT_LIMIT beats the hand edit
#   4. a model new to the config gets the default while the old one keeps its
#      edit
#   5. the architecture cap still bounds a preserved value
#   6. a .env.local OPENCODE_CONTEXT_LIMIT overrides the built-in default
#      (regression for the source-before-defaults ordering)
#   7. an unchanged rerun rewrites nothing
#
# Nothing outside the temp directory is touched: the installer and the stub
# server run inside it, and the copy ships without the repo's .env.local.
#
# Author: Alister Lewis-Bowen <alister@lewis-bowen.org>
# Version: 1.0.0
# Date: 2026-11-19
# Usage: ./opencode/test_install.sh
#
# Exit codes:
#   0 - all checks passed
#   1 - at least one check failed
#   2 - environment problem (missing tool, stub server did not start)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(realpath "$SCRIPT_DIR" 2>/dev/null || printf '%s' "$SCRIPT_DIR")"

for tool in curl jq python3; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'required tool not found: %s\n' "$tool" >&2
        exit 2
    fi
done

T="$(mktemp -d)"
SERVER_PID=""
cleanup() {
    if [[ -n "$SERVER_PID" ]]; then
        kill "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "$T"
}
trap cleanup EXIT

# --- sandbox: a copy of the opencode/ directory + a stub claude/CLAUDE.md ---
mkdir -p "$T/repo/opencode" "$T/repo/claude" "$T/home"
cp -R "$SCRIPT_DIR/." "$T/repo/opencode/"
printf '@AGENTS.md\n' > "$T/repo/claude/CLAUDE.md"
# Deliberately no .env.local in the copy: scenario 6 controls it.

# --- stub model server: /v1/models from models.txt, /api/show from caps.txt ---
PORT="$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()')"
printf 'm1\n' > "$T/models.txt"
: > "$T/caps.txt"
cat > "$T/server.py" <<'PY'
import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

ROOT = os.environ["ROOT"]

def read_lines(name):
    try:
        with open(os.path.join(ROOT, name)) as f:
            return [line.strip() for line in f if line.strip()]
    except FileNotFoundError:
        return []

class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def _send(self, obj):
        body = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/v1/models":
            self._send({"data": [{"id": m} for m in read_lines("models.txt")]})
        else:
            self._send({})

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        req = json.loads(self.rfile.read(length) or b"{}")
        if self.path == "/api/show":
            caps = dict(line.split("=", 1) for line in read_lines("caps.txt") if "=" in line)
            info = {}
            if req.get("model") in caps:
                info["qwen3.ctx.context_length"] = caps[req["model"]]
            self._send({"model_info": info})
        else:
            self._send({})

HTTPServer(("127.0.0.1", int(os.environ["PORT"])), Handler).serve_forever()
PY
ROOT="$T" PORT="$PORT" python3 "$T/server.py" &
SERVER_PID="$!"
for _ in {1..50}; do
    if curl -s -o /dev/null "http://127.0.0.1:$PORT/v1/models"; then
        break
    fi
    sleep 0.1
done
if ! curl -sf -o /dev/null "http://127.0.0.1:$PORT/v1/models"; then
    printf 'stub model server did not come up on port %s\n' "$PORT" >&2
    exit 2
fi

CONFIG="$T/home/.config/opencode/opencode.json"
PASS=0
FAIL=0

run_install() {
    env -i HOME="$T/home" PATH="$PATH" TERM="${TERM:-dumb}" \
        LOCAL_ENDPOINT="http://127.0.0.1:$PORT/v1" \
        "$@" \
        bash "$T/repo/opencode/install.sh" > "$T/run.log" 2>&1
    local rc=$?
    if [[ $rc -ne 0 ]]; then
        sed 's/^/    /' "$T/run.log" | tail -15
        printf 'install.sh exited %s\n' "$rc" >&2
    fi
    return "$rc"
}

die() {
    printf 'FATAL: %s\n' "$1" >&2
    printf 'passed: %s  failed: %s\n' "$PASS" "$FAIL"
    exit 1
}

check() {
    local label="$1" expr="$2" want="$3" got
    got="$(jq -r "$expr" "$CONFIG")"
    if [[ "$got" == "$want" ]]; then
        printf 'ok   %s\n' "$label"
        PASS=$((PASS + 1))
    else
        printf 'FAIL %s: got %s, want %s\n' "$label" "$got" "$want"
        FAIL=$((FAIL + 1))
    fi
}

hand_edit() {
    jq '.providers.ollama.models.m1.limit.context = 262144' "$CONFIG" > "$CONFIG.tmp"
    mv "$CONFIG.tmp" "$CONFIG"
}

file_hash() {
    python3 -c 'import hashlib, sys; print(hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest())' "$1"
}

echo "1: a fresh install writes the defaults"
run_install || die "first install failed"
check "m1 context is the default" '.providers.ollama.models.m1.limit.context' 131072
check "m1 output is the default" '.providers.ollama.models.m1.limit.output' 32768

echo "2: a hand-edited limit.context survives a rerun"
hand_edit
run_install || die "rerun failed"
check "m1 context kept" '.providers.ollama.models.m1.limit.context' 262144

echo "3: an explicit OPENCODE_CONTEXT_LIMIT beats the hand edit"
hand_edit
run_install OPENCODE_CONTEXT_LIMIT=8192 || die "rerun with env failed"
check "m1 context is the env value" '.providers.ollama.models.m1.limit.context' 8192
hand_edit

echo "4: a new model gets the default, the old one keeps its edit"
printf 'm1\nm2\n' > "$T/models.txt"
run_install || die "rerun with new model failed"
check "m2 context is the default" '.providers.ollama.models.m2.limit.context' 131072
check "m1 context kept" '.providers.ollama.models.m1.limit.context' 262144

echo "5: the architecture cap bounds a preserved value"
printf 'm1=32768\n' > "$T/caps.txt"
run_install || die "rerun with arch cap failed"
check "m1 context capped to the arch value" '.providers.ollama.models.m1.limit.context' 32768
: > "$T/caps.txt"
hand_edit

echo "6: a .env.local OPENCODE_CONTEXT_LIMIT overrides the built-in default"
rm -rf "$T/home/.config"
printf 'OPENCODE_CONTEXT_LIMIT=8192\n' > "$T/repo/.env.local"
run_install || die "rerun with .env.local failed"
check "m1 context is the .env.local value" '.providers.ollama.models.m1.limit.context' 8192
check "m2 context is the .env.local value" '.providers.ollama.models.m2.limit.context' 8192
rm -f "$T/repo/.env.local"

echo "7: an unchanged rerun rewrites nothing"
before="$(file_hash "$CONFIG")"
run_install || die "final rerun failed"
after="$(file_hash "$CONFIG")"
if [[ "$before" == "$after" ]]; then
    printf 'ok   rerun changed nothing\n'
    PASS=$((PASS + 1))
else
    printf 'FAIL rerun rewrote the config\n'
    FAIL=$((FAIL + 1))
fi

echo
printf 'passed: %s  failed: %s\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi
