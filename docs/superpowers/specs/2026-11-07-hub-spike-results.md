# Hub Phase 0 spike results

Date: 2026-11-08 · Claude Code 2.1.319 · macOS · scratch repo under the session scratchpad (`hub-spike/proj`, deleted after the spike). Lamps as listed in the design doc §8 and plan Task 0. Worker profile: `.claude/agents/hub-worker.md` with `model: sonnet` and the four-line report block in the body.

| Lamp | Result | Evidence |
|---|---|---|
| A · `--agent hub-worker` under `claude -p` with stream-json | PASS | `a.jsonl`: init line `model=claude-sonnet-5-5` (agent model applied), `hub-worker` in `agents`; one `tool_use`; `result.subtype=success`; result text ends with the four-line block; worker obeyed the agent body (wrote `progress.log` before editing). Exit 0, 2 turns, $0.23. |
| B · `--resume <uuid>` keeps history | PASS | `b.jsonl`: answered `hello.txt`; same `session_id`; agent model and report block preserved on resume without repeating `--agent`. |
| C · interrupt then resume | PASS, with two corrections | `kill -INT` on the `claude -p` process stopped it within a second: 10 of 30 files written before, still 10 after. **Exit code was 0, not 130/143**, and the stream ended with `result.subtype=error_during_execution`, `result=null`. Resume with the "Interrupted by Din…" preamble: worker read `progress.log` + `git status`, listed f01–f10 exactly, created nothing, mtimes unchanged (`diff` of `stat` output empty). |
| C′ · permission mode for file writes | FAIL under plain `auto`, PASS with `--allowedTools` | First attempt: the worker issued 16 parallel `Write` calls; every one came back `is_error=true` "The user doesn't want to proceed with this tool use" (auto classifier denial, `permission_denials=[]`), the round ended `error_during_execution` with no files and no report. A single `Write` under `auto` is allowed. With `--allowedTools "Write,Edit,Read,Glob,Grep"` added, all `Write` calls passed; `Bash` stays under the `auto` classifier. |
| D · confinement to one allowed file | PASS | Prompt "change only README.md": `git status --porcelain` diff before/after shows only ` M README.md` (plus `progress.log`, which the agent body mandates). Worker used `Bash echo >>` rather than `Edit`, so confinement is by instruction, not by tool. |
| E · event delivery into the Router via `Monitor` (`tail -n0 -F events.log`, 30-min timeout) | 2-min line PASS; 25-min line: PENDING_E | Line appended at t+2 min arrived as a Monitor event in the Router's context within a second. PENDING_E_DETAIL |
| F · Telegram | send PASS; receive deferred | Token lives in `~/.claude/channels/telegram/.env` (mode 0600); only `getUpdates` is exclusive per token (plugin `server.ts` comments, 409 handling), `sendMessage` is not. A direct Bot API `sendMessage` from a plain shell process to the configured chat id returned `ok=true, message_id=247`. So `hub propose` can notify Telegram itself without a plugin instance. The inbound half (reply arrives as a channel message in a `--channels` session) is checked at the first Router start in Task 10; the plugin failed to connect in this session and no poller process was running. |

## Decided values (read by `hub init`)

```
WORKER_AGENT_MODE=agent
EVENT_DELIVERY=PENDING_E_VALUE
```

## Corrections carried into the plan

1. Worker invocation gains `--allowedTools "Write,Edit,Read,Glob,Grep"` next to `--permission-mode auto` (Global Constraints + Task 4). Without it a burst of parallel edits is denied and the round dies without a report.
2. `hub send`/`hub stop` must not rely on the exit code to recognise an interrupted round. Dispatch records `interrupted=1` in `.runs/<T>/state` before sending SIGINT and treats `result.subtype=error_during_execution` with that flag as `interrupted`, without it as `failed` (Task 4, Task 5).
3. `events.py final` must tolerate `result=null` and `subtype=error_during_execution` (return `status=unknown-report`, `note=<errors[0]>`), and `permission_denials` may be empty even when every tool call was denied, so denial detection reads `tool_result.is_error` with the "doesn't want to proceed" text (Task 3).
4. Telegram sending from the CLI: `hub propose` posts via Bot API using the token from `~/.claude/channels/telegram/.env` and the chat id from `$APPROVALS_DIR/config.md`, both read at call time, never logged (Task 8). The Router's own plugin tool remains the path for conversational replies.
5. Cost note: each worker round reads ~55k cached tokens of global system prompt (all installed plugins, agents and hooks are inherited; 9 hook invocations per round). Resumed single-turn rounds cost $0.23–0.44 on sonnet. Not a blocker for Phase 1; a trimmed `CLAUDE_CONFIG_DIR` for workers is a Phase 2 candidate.
