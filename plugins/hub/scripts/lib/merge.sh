# merge.sh — hub eval / propose / merge. bash 3.2 safe; never uses eval.

# hub_git <dir> <git args...> — git -C wrapper.
hub_git() {
  local d="$1"
  shift
  git -C "$d" "$@"
}

# hub_eval_block <ticket> — prints the ticket's check block (spec eval.md wins), or nothing.
hub_eval_block() {
  local spec
  spec=$(python3 "$HUB_LIB/tickets.py" get "$1" spec) || return 1
  if [ -n "$spec" ] && [ -f "$spec/eval.md" ]; then
    python3 -c '
import re, sys
m = re.search(r"```check[^\n]*\n(.*?)\n```", open(sys.argv[1], encoding="utf-8").read(), re.S)
if m:
    print(m.group(1))
' "$spec/eval.md"
    return 0
  fi
  python3 -c '
import sys
sys.path.insert(0, sys.argv[1])
import tickets
b = tickets.load(sys.argv[2])["eval_check"]
if b:
    print(b)
' "$HUB_LIB" "$1"
}

hub__main_branch() {
  local proj
  proj=$(python3 "$HUB_LIB/tickets.py" get "$1" project)
  python3 "$HUB_LIB/tickets.py" projects | python3 -c 'import json,sys; print(json.load(sys.stdin).get(sys.argv[1],{}).get("main","main"))' "$proj"
}

hub__tk() { python3 "$HUB_LIB/tickets.py" get "$1" "$2"; }
hub__ts() { python3 "$HUB_LIB/tickets.py" set "$1" "$2" "$3"; }

# hub eval <ticket>
cmd_eval() {
  local t="${1:-}" block run wt dir script out pid waited limit timedout rc verdict first
  [ -n "$t" ] || hub_die "usage: hub eval <ticket>"
  python3 "$HUB_LIB/tickets.py" get "$t" status >/dev/null || exit 1
  block=$(hub_eval_block "$t") || exit 1
  if [ -z "$block" ]; then
    echo "n/a"
    hub__ts "$t" eval "n/a"
    return 0
  fi
  run="$HUB_DIR/.runs/$t"
  if [ -f "$run/worktree" ]; then dir=$(cat "$run/worktree"); else dir=$(hub__tk "$t" path); fi
  [ -d "$dir" ] || hub_die "eval: directory not found: $dir"
  script=$(mktemp "${TMPDIR:-/tmp}/hub-eval.XXXXXX") || hub_die "mktemp failed"
  out=$(mktemp "${TMPDIR:-/tmp}/hub-eval-out.XXXXXX") || hub_die "mktemp failed"
  printf '%s\n' "$block" > "$script"
  limit="${HUB_EVAL_TIMEOUT_S:-600}"
  timedout=0
  ( cd "$dir" || exit 1; exec bash -e "$script" ) > "$out" 2>&1 &
  pid=$!
  waited=0
  while hub_pid_alive "$pid"; do
    if [ "$waited" -ge "$limit" ]; then
      timedout=1
      pkill -TERM -P "$pid" 2>/dev/null
      kill -TERM "$pid" 2>/dev/null
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid" 2>/dev/null
  rc=$?
  if [ "$timedout" = 1 ]; then
    { echo "eval: timed out after $limit s"; cat "$out"; } > "$out.t"
    mv -f "$out.t" "$out"
    rc=1
  fi
  if [ "$rc" -eq 0 ]; then verdict=green; else verdict=red; fi
  first=$(head -n 1 "$out")
  echo "$verdict"
  head -n 20 "$out"
  hub__ts "$t" eval "$verdict"
  hub_log "$t" "eval: $verdict${first:+ ($first)}"
  rm -f -- "$script" "$out"
  [ "$verdict" = green ]
}

# hub propose <ticket> "<recommendation>" [--push] [--no-telegram]
cmd_propose() {
  local t="" rec="" push=0 tg=1 a n=0 f main title id num short line
  local envf token chat api
  for a in "$@"; do
    case "$a" in
      --push) push=1 ;;
      --no-telegram) tg=0 ;;
      *) if [ -z "$t" ]; then t="$a"; elif [ -z "$rec" ]; then rec="$a"; else hub_die "propose: unexpected argument: $a"; fi ;;
    esac
  done
  [ -n "$t" ] && [ -n "$rec" ] || hub_die 'usage: hub propose <ticket> "<recommendation>" [--push] [--no-telegram]'
  [ "$(hub__tk "$t" status)" = ready ] || { echo "hub: $t is not ready; nothing to propose" >&2; exit 1; }
  [ "${HUB_TELEGRAM:-1}" = 0 ] && tg=0
  mkdir -p "$APPROVALS_DIR" || hub_die "cannot create $APPROVALS_DIR"
  for f in "$APPROVALS_DIR/$t"-*.md; do [ -e "$f" ] && n=$((n + 1)); done
  num=$((n + 1))
  id="$t-$num"
  main=$(hub__main_branch "$t")
  title=$(hub__tk "$t" title)
  {
    echo "---"
    echo "id: $id"
    echo "status: pending"
    echo "created: $(date '+%Y-%m-%d %H:%M')"
    echo "requested_by: hub-router"
    echo "project: $(hub__tk "$t" path)"
    echo "ticket: $t"
    echo "---"
    echo
    echo "## Action"
    echo "Merge ticket $t ($title) into $main$([ "$push" = 1 ] && echo ' and push')."
    echo
    echo "## Exact steps"
    echo '```bash'
    echo "hub merge $t$([ "$push" = 1 ] && echo ' --push')"
    echo '```'
    echo
    echo "## Context"
    printf '%s\n' "$rec"
  } > "$APPROVALS_DIR/$id.md"
  short=$(printf '%s' "$rec" | awk '{for(i=1;i<=NF;i++){if(++c>100)exit; printf "%s%s",(c>1?" ":""),$i}}')
  line="🔐 Approval needed [$id] — $short. Reply: yes T-$((10#${t#T-})) · approve $id · reject $id"
  echo "$line"
  hub_log "$t" "proposed $id"
  if [ "$tg" = 1 ]; then
    envf="${TELEGRAM_ENV_FILE:-$HOME/.claude/channels/telegram/.env}"
    token=""; chat=""
    [ -f "$envf" ] && token=$(grep '^TELEGRAM_BOT_TOKEN=' "$envf" | tail -n 1 | cut -d= -f2- | tr -d "\"'")
    [ -f "$APPROVALS_DIR/config.md" ] && chat=$(grep '^telegram_chat_id:' "$APPROVALS_DIR/config.md" | head -n 1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d "\"' ")
    if [ -z "$token" ] || [ -z "$chat" ]; then
      echo "telegram: not configured" >&2
    else
      api="${HUB_TELEGRAM_API:-https://api.telegram.org}"
      curl -s -S --max-time 20 -X POST "$api/bot${token}/sendMessage" \
        --data-urlencode "chat_id=${chat}" --data-urlencode "text=${line}" -o /dev/null \
        || echo "telegram: send failed" >&2
    fi
    token=""
  fi
  return 0
}

# hub merge <ticket> [--push]
cmd_merge() {
  local t="" push=0 a st iso repo wt main title run cur conflicts mout rc
  for a in "$@"; do
    case "$a" in
      --push) push=1 ;;
      *) if [ -z "$t" ]; then t="$a"; else hub_die "merge: unexpected argument: $a"; fi ;;
    esac
  done
  [ -n "$t" ] || hub_die "usage: hub merge <ticket> [--push]"
  st=$(hub__tk "$t" status) || exit 1
  [ "$st" = ready ] || hub_die "merge: $t is '$st', not ready"
  run="$HUB_DIR/.runs/$t"
  repo=$(hub__tk "$t" path)
  title=$(hub__tk "$t" title)
  main=$(hub__main_branch "$t")
  if [ -f "$run/worktree" ]; then
    wt=$(cat "$run/worktree")
    [ -d "$wt" ] || hub_die "merge: worktree missing: $wt"
    cur=$(hub_git "$repo" rev-parse --abbrev-ref HEAD) || hub_die "merge: cannot read branch of $repo"
    [ "$cur" = "$main" ] || hub_die "merge: $repo is on '$cur', expected '$main' checked out; nothing merged"
    if [ -n "$(hub_git "$wt" status --porcelain)" ]; then
      hub_git "$wt" add -A && hub_git "$wt" commit -q -m "hub($t): $title" || hub_die "merge: commit in worktree failed"
    fi
    if ! mout=$(hub_git "$wt" merge --no-edit "$main" 2>&1); then
      conflicts=$(hub_git "$wt" diff --name-only --diff-filter=U | tr '\n' ' ')
      hub_git "$wt" merge --abort 2>&1
      hub__ts "$t" status conflict
      hub_log "$t" "conflict merging $main: ${conflicts:-unknown files}"
      echo "conflict merging $main into hub/$t: ${conflicts:-unknown files}"
      exit 2
    fi
    rc=0
    cmd_eval "$t" || rc=$?
    [ "$rc" -eq 0 ] || exit 1
    if ! mout=$(hub_git "$repo" merge --no-ff -m "merge hub/$t: $title" "hub/$t" 2>&1); then
      hub_git "$repo" merge --abort 2>&1
      hub_die "merge: merging hub/$t into $main failed: $mout"
    fi
    hub_git "$repo" worktree remove --force "$wt" || hub_die "merge: worktree remove failed"
    hub_git "$repo" branch -q -d "hub/$t" || hub_die "merge: branch delete failed"
    [ "$push" = 1 ] && { hub_git "$repo" push || hub_die "merge: push failed"; }
    hub__ts "$t" status done
    rm -f -- "$run/worktree"
    hub_log "$t" "merged hub/$t into $main"
  else
    local paths=() p
    while IFS= read -r p; do
      [ -n "$p" ] && paths=("${paths[@]}" "$p")
    done < <(hub__tk "$t" files | tr ',' '\n')
    if [ "${#paths[@]}" -eq 0 ] && [ -f "$run/final.json" ]; then
      while IFS= read -r p; do
        [ -n "$p" ] && paths=("${paths[@]}" "$p")
      done < <(python3 -c '
import json, re, sys
for x in json.load(open(sys.argv[1])).get("files") or []:
    x = re.sub(r"\s+\((new|changed)\)$", "", str(x).strip())
    if x and x != "none":
        print(x)
' "$run/final.json")
    fi
    [ "${#paths[@]}" -gt 0 ] || hub_die "no files to commit"
    hub_git "$repo" add -- "${paths[@]}" || hub_die "merge: git add failed"
    hub_git "$repo" commit -q -m "hub($t): $title" -- "${paths[@]}" || hub_die "merge: git commit failed"
    [ "$push" = 1 ] && { hub_git "$repo" push || hub_die "merge: push failed"; }
    hub__ts "$t" status done
    hub_log "$t" "committed ${#paths[@]} file(s)"
  fi
  echo "$(hub_now) done $t" >> "$HUB_DIR/.runs/events.log"
  echo "done $t"
}
