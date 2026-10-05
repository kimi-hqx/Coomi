#!/bin/sh
# 轮询 CoomiDev APK 工作流状态，直到结束。
# 用法：watch-run.sh <run_id> [最大轮次]
set -u
RUN="${1:?run id required}"
MAX="${2:-200}"
export GH_TOKEN="$(tr -d '\n' < /tmp/.ghtok)"
REPO=kimi-hqx/Coomi
i=0
last=""
while [ "$i" -lt "$MAX" ]; do
    i=$((i + 1))
    info=$(gh api "/repos/$REPO/actions/runs/$RUN" 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    print('NA|unknown|unknown'); raise SystemExit
print('|'.join([d.get('status') or 'NA', d.get('conclusion') or 'pending', str(d.get('run_started_at'))]))
")
    status=$(printf '%s' "$info" | cut -d'|' -f1)
    concl=$(printf '%s' "$info" | cut -d'|' -f2)
    if [ "$info" != "$last" ]; then
        echo "[$(date -u +%H:%M:%S)] run=$RUN status=$status conclusion=$concl"
        last="$info"
    fi
    case "$status" in
        completed)
            echo "[$(date -u +%H:%M:%S)] DONE conclusion=$concl"
            gh api "/repos/$REPO/actions/runs/$RUN/jobs" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
for j in d.get('jobs', []):
    print('JOB', j['name'], '->', j['status'], j.get('conclusion'))
    for s in j.get('steps', []):
        print('   ', s['number'], s['name'], '->', s['status'], s.get('conclusion'))
"
            exit 0
            ;;
    esac
    sleep 25
done
echo "[$(date -u +%H:%M:%S)] monitor timeout"
