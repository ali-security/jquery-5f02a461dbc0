#!/bin/bash
#
# Runs the jQuery QUnit suite (test/index.html) unattended and fails the build
# when any test fails.
#
# jQuery 1.11 shipped no CI-runnable test command: `npm test` is `grunt`, which
# only lints and builds, and the unit tests were farmed out to TestSwarm
# browsers. This driver stands in for TestSwarm: PHP serves the suite (the ajax
# tests need the .php fixtures in test/data), headless Chrome runs it under
# --virtual-time-budget so the timer-driven tests finish in seconds, and the
# resulting DOM is parsed for QUnit's own pass/fail counts.
#
# Usage: test/run-ci-tests.sh
set -euo pipefail

PORT="${QUNIT_PORT:-8321}"
CHROME="${CHROME_BIN:-google-chrome}"
ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
DOM="$( mktemp -t qunit-dom-XXXXXX.html )"

cd "$ROOT"

php -S "127.0.0.1:${PORT}" -t . > /tmp/qunit-php-server.log 2>&1 &
PHP_PID=$!
trap 'kill "$PHP_PID" 2>/dev/null || true' EXIT

for _ in $(seq 1 30); do
	if curl -sf "http://127.0.0.1:${PORT}/test/index.html" -o /dev/null; then
		break
	fi
	sleep 1
done

echo "=== jQuery QUnit suite: $("$CHROME" --version) ==="

"$CHROME" \
	--headless \
	--no-sandbox \
	--disable-gpu \
	--disable-dev-shm-usage \
	--virtual-time-budget=600000 \
	--dump-dom "http://127.0.0.1:${PORT}/test/index.html" > "$DOM"

# QUnit writes its summary and one <li class="fail"> per failing test into the
# page; --dump-dom hands us the finished document, so the DOM is the report.
python3 - "$DOM" <<'PYTHON'
import re
import sys

dom = open(sys.argv[1], encoding="utf-8", errors="replace").read()

summary = re.search(
    r'<span class="passed">(\d+)</span> assertions of '
    r'<span class="total">(\d+)</span> passed, '
    r'<span class="failed">(\d+)</span> failed',
    dom,
)
if not summary:
    print("QUnit never reported a result - the suite did not finish")
    sys.exit(1)

passed, total, failed = (int(g) for g in summary.groups())

names = []
for match in re.finditer(r'class="fail" id="qunit-test-output\d+">(.{0,300})', dom, re.S):
    text = " ".join(re.sub(r"<[^>]+>", " ", match.group(1)).split())
    names.append(re.sub(r"\(\s*\d+\s*,.*$", "", text).strip())

for name in names:
    print("not ok - %s" % name)

print("Tests completed: %d assertions of %d passed, %d failed" % (passed, total, failed))

if total == 0:
    print("QUnit ran no assertions - the suite did not load")
    sys.exit(1)
sys.exit(1 if failed else 0)
PYTHON
