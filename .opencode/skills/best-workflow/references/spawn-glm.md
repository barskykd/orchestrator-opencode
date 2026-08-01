== How to spawn sub-agents ==

```bash
<skill folder>/tools/spawn-glm.sh -n NAME -f PROMPT_FILE [-m MODEL] [--pi]
```
`-m` is optional — when omitted, the agent uses harness configured default model. Use `-m MODEL` to override with a specific model. Returns `SPAWNED|name|pid|log_file`. Backgrounds immediately. Report: `tmp/{NAME}-report.md`, log: `tmp/{NAME}-log.txt`. Also writes to `tmp/{NAME}-status.txt` (reliable on Windows — stdout can be lost when parallel `.cmd` processes launch). Use `--pi` if running inside pi harness.

**Wait:**
```bash
<skill folder>/tools/wait-glm.sh name1:$PID1 name2:$PID2 name3:$PID3
```
Blocks until all finish (Bash timeout: 600000). Do NOT use bare `wait` or `sleep` + poll loops. Prefer `name:pid` format — enables progress monitoring (first at 30s, then every 60s) and STALLED detection (0-byte log after 2min). Bare PIDs still work but skip log monitoring. If Bash times out before agents finish, re-invoke with same arguments — this is normal for long-running agents. **Planner, volume-splitter, and organizer agents read many files in a single tool call, producing bursts of log growth separated by long pauses where the agent is thinking, not stuck. A Stage 0 agent showing STALLED after 2 minutes of no log growth but with healthy early activity (file reads, grep, wc -l) is not stalled — wait for the full Bash timeout. Only kill and re-spawn if the log is empty from the start or grows zero bytes for 10+ minutes.**



