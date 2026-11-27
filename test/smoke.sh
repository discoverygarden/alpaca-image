#!/usr/bin/env bash
# Smoke test: Alpaca starts its routes on this JVM and exposes the JMX exporter.
# No broker is provided, so JMS connection errors are expected and ignored; we
# only fail on startup/runtime-compatibility problems.
# Usage: test/smoke.sh <image>
set -euo pipefail
IMAGE="${1:?usage: $0 <image>}"
NAME="alpaca-smoke-$$"
trap 'rc=$?; [ $rc -ne 0 ] && docker logs "$NAME" >&2 2>&1; docker rm -f "$NAME" >/dev/null 2>&1; exit $rc' EXIT

docker run -d --name "$NAME" "$IMAGE" >/dev/null

echo "waiting for Alpaca to start..."
for _ in $(seq 1 60); do
  docker logs "$NAME" 2>&1 | grep -q 'Alpaca started\.' && started=1 && break
  [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = "true" ] || { echo "FAIL: container exited" >&2; exit 1; }
  sleep 1
done
[ "${started:-0}" = "1" ] || { echo "FAIL: 'Alpaca started.' not logged" >&2; exit 1; }
echo "ok: Alpaca started"

# Let it run past the first JMS retry cycle, then check it is still healthy.
sleep 8
[ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = "true" ] || { echo "FAIL: container exited after start" >&2; exit 1; }

if docker logs "$NAME" 2>&1 | grep -E 'UnsupportedClassVersionError|UnsatisfiedLinkError|InaccessibleObjectException|NoClassDefFoundError|ClassNotFoundException|Exception in thread "main"'; then
  echo "FAIL: JVM compatibility error in logs" >&2
  exit 1
fi
echo "ok: no JVM compatibility errors"

# Capture first: grep -q closing the pipe early would trip pipefail via curl.
metrics="$(docker exec "$NAME" curl -sf http://localhost:3001/metrics)"
grep -qE '^(jvm|java_lang)_' <<<"$metrics" \
  || { echo "FAIL: JMX exporter metrics missing on :3001" >&2; exit 1; }
echo "ok: JMX exporter serving metrics"
echo "smoke test passed"
