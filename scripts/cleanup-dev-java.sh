#!/usr/bin/env bash
set -euo pipefail

# Kill java app.jar processes if:
# 1) User has been idle > 5 minutes (via logind), OR
# 2) Process is older than 30 minutes (orphan guard)

IDLE_THRESHOLD=300
AGE_THRESHOLD=1800

# --- Idle detection via logind ---
idle_seconds=0
if command -v loginctl &>/dev/null; then
    session=$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}' | head -1)
    if [[ -n "$session" ]]; then
        idle_usec=$(loginctl show-session "$session" -p IdleSinceHint 2>/dev/null | cut -d= -f2)
        if [[ -n "$idle_usec" && "$idle_usec" != "0" ]]; then
            now_usec=$(($(date +%s%N) / 1000))
            idle_seconds=$(( (now_usec - idle_usec) / 1000000 ))
        fi
    fi
fi

user_idle=false
[[ $idle_seconds -ge $IDLE_THRESHOLD ]] && user_idle=true

# Find java app.jar processes that are NOT IntelliJ (PID 1580)
while IFS='|' read -r pid etime; do
    # skip IntelliJ
    [[ "$pid" == "1580" ]] && continue

    # parse elapsed time from ps etime format
    age_seconds=0
    if [[ "$etime" == *-* ]]; then
        days=${etime%%-*}
        rest=${etime#*-}
        age_seconds=$(( days * 86400 + $(date -d "1970-01-01 $rest" +%s 2>/dev/null || echo 0) ))
    elif [[ "$etime" == *:*:* ]]; then
        IFS=: read -r h m s <<< "$etime"
        age_seconds=$(( 10#$h * 3600 + 10#$m * 60 + 10#$s ))
    elif [[ "$etime" == *:* ]]; then
        IFS=: read -r m s <<< "$etime"
        age_seconds=$(( 10#$m * 60 + 10#$s ))
    fi

    # kill if user idle, or process is old enough
    if [[ "$user_idle" == true || $age_seconds -ge $AGE_THRESHOLD ]]; then
        kill "$pid" 2>/dev/null || true
    fi
done < <(ps -o pid,etime --no-headers -C java --sort=-etime 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1 "|" $2}')