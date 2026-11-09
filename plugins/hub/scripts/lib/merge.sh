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

# hub__merging <dir> — succeeds when a merge is in progress in that checkout.
hub__merging() {
  local h
  h=$(git -C "$1" rev-parse -q --verify MERGE_HEAD)
  [ $? -eq 0 ] && [ -n "$h" ]
}

# hub eval <ticket>
cmd_eval() {
  local t="${1:-}" block run dir script out pid waited limit timedout rc verdict first
  [ -n "$t" ] || hub_die "usage: hub eval <ticket>"
  first=$(hub__tk "$t" status) || exit 1
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
  case "$limit" in ''|*[!0-9]*) limit=600 ;; esac
  timedout=0
  set -m
  ( cd "$dir" || exit 1; exec bash -e "$script" ) </dev/null > "$out" 2>&1 &
  pid=$!
  set +m
  waited=0
  {
  while hub_pid_alive "$pid"; do
    if [ "$waited" -ge "$limit" ]; then
      timedout=1
      kill -TERM -- "-$pid" 2>/dev/null
      kill -TERM "$pid" 2>/dev/null
      sleep 2
      if hub_pid_alive "$pid"; then
        kill -KILL -- "-$pid" 2>/dev/null
        kill -KILL "$pid" 2>/dev/null
      fi
      break
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
  rc=$?
  } 2>/dev/null
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
  local t="" rec="" push=0 tg=1 a n=1 f main title id short line body hubabs appabs
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
  appabs=$(cd "$APPROVALS_DIR" && pwd) || hub_die "cannot read $APPROVALS_DIR"
  hubabs=$(cd "$HUB_DIR" && pwd) || hub_die "cannot read $HUB_DIR"
  main=$(hub__main_branch "$t")
  title=$(hub__tk "$t" title)
  while :; do
    id="$t-$n"
    f="$appabs/$id.md"
    if [ ! -e "$f" ]; then
      body=$(
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
        # absolute and quoted: the record is run verbatim from any cwd, hub need not be on PATH
        echo "\"$hubabs/bin/hub\" merge $t$([ "$push" = 1 ] && echo ' --push')"
        echo '```'
        echo
        echo "## Context"
        printf '%s\n' "$rec"
      )
      # noclobber: a concurrent propose that took this number makes the write fail; try the next one.
      if ( set -C; printf '%s\n' "$body" > "$f" ) 2>/dev/null; then break; fi
      [ -e "$f" ] || hub_die "propose: cannot write $f"
    fi
    n=$((n + 1))
    [ "$n" -le 1000 ] || hub_die "propose: too many approval records for $t"
  done
  short=$(printf '%s' "$rec" | awk '{for(i=1;i<=NF;i++){if(++c>100)exit; printf "%s%s",(c>1?" ":""),$i}}')
  line="🔐 Approval needed [$id] — $short. Reply: yes T-$((10#${t#T-})) · approve $id · reject $id"
  echo "$line"
  echo "record: $f"
  hub_log "$t" "proposed $id"
  if [ "$tg" = 1 ]; then
    envf="${TELEGRAM_ENV_FILE:-$HOME/.claude/channels/telegram/.env}"
    token=""; chat=""
    [ -f "$envf" ] && token=$(grep -E '^(export[[:space:]]+)?TELEGRAM_BOT_TOKEN=' "$envf" | tail -n 1 | sed -E 's/^(export[[:space:]]+)?TELEGRAM_BOT_TOKEN=//' | tr -d '\r' | tr -d "\"'")
    [ -f "$APPROVALS_DIR/config.md" ] && chat=$(grep '^telegram_chat_id:' "$APPROVALS_DIR/config.md" | head -n 1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d "\"' \r")
    if [ -z "$token" ] || [ -z "$chat" ]; then
      echo "telegram: not configured" >&2
    else
      api="${HUB_TELEGRAM_API:-https://api.telegram.org}"
      # the URL (with the token) goes through a curl config on stdin, never argv
      printf 'url = "%s/bot%s/sendMessage"\n' "$api" "$token" \
        | curl -s -S -f --max-time 20 -K - -X POST \
            --data-urlencode "chat_id=${chat}" --data-urlencode "text=${line}" -o /dev/null \
        || echo "telegram: send failed" >&2
    fi
    token=""
  fi
  return 0
}

# hub merge <ticket> [--push]
cmd_merge() {
  local t="" push=0 a st repo wt main title run cur conflicts mout rc perr
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
  # pre-flight: the main checkout must be on <main> with no merge in progress
  cur=$(hub_git "$repo" rev-parse --abbrev-ref HEAD) || hub_die "merge: cannot read branch of $repo"
  [ "$cur" = "$main" ] || hub_die "merge: $repo is on '$cur', expected '$main' checked out; nothing merged"
  if hub__merging "$repo"; then hub_die "merge: $repo has a merge in progress; nothing merged"; fi
  if [ -f "$run/worktree" ]; then
    wt=$(cat "$run/worktree")
    [ -d "$wt" ] || hub_die "merge: worktree missing: $wt"
    if hub__merging "$wt"; then hub_die "merge: $wt has a merge in progress; nothing merged"; fi
    if [ -n "$(hub_git "$wt" status --porcelain)" ]; then
      hub_git "$wt" add -A && hub_git "$wt" commit -q -m "hub($t): $title" || hub_die "merge: commit in worktree failed"
    fi
    if ! mout=$(hub_git "$wt" merge --no-edit "$main" 2>&1); then
      conflicts=$(hub_git "$wt" diff --name-only --diff-filter=U | tr '\n' ' ')
      conflicts="${conflicts% }"
      if hub__merging "$wt"; then hub_git "$wt" merge --abort; fi
      hub__ts "$t" status conflict
      hub_log "$t" "conflict merging $main into hub/$t: ${conflicts:-unknown files}"
      echo "conflict merging $main into hub/$t: ${conflicts:-unknown files}"
      exit 2
    fi
    rc=0
    cmd_eval "$t" || rc=$?
    [ "$rc" -eq 0 ] || exit 1
    if hub__merging "$repo"; then hub_die "merge: $repo has a merge in progress; nothing merged"; fi
    if ! mout=$(hub_git "$repo" merge --no-ff -m "merge hub/$t: $title" "hub/$t" 2>&1); then
      if hub__merging "$repo"; then hub_git "$repo" merge --abort; fi
      hub_die "merge: merging hub/$t into $main failed: $mout"
    fi
    hub_git "$repo" worktree remove --force "$wt" || hub_die "merge: worktree remove failed"
    hub_log "$t" "worktree removed (uncommitted eval edits discarded)"
    hub_git "$repo" branch -q -d "hub/$t" || hub_die "merge: branch delete failed"
    hub__ts "$t" status done
    rm -f -- "$run/worktree"
    hub_log "$t" "merged hub/$t into $main"
  else
    local paths=() p
    while IFS= read -r p; do
      [ -n "$p" ] && paths=("${paths[@]}" "$p")
    done < <(hub__tk "$t" files | tr ',' '\n')
    # Only the ticket's own list counts; the worker's self-reported Files: line never does.
    [ "${#paths[@]}" -gt 0 ] || hub_die "ticket lists no files; set them with hub set $t files a,b"
    for p in "${paths[@]}"; do echo "committing: $p"; done
    hub_git "$repo" --literal-pathspecs add -- "${paths[@]}" || hub_die "merge: git add failed"
    hub_git "$repo" --literal-pathspecs commit -q -m "hub($t): $title" -- "${paths[@]}" || hub_die "merge: git commit failed"
    hub__ts "$t" status done
    hub_log "$t" "committed ${#paths[@]} file(s)"
  fi
  echo "$(hub_now) done $t" >> "$HUB_DIR/.runs/events.log"
  echo "done $t"
  if [ "$push" = 1 ]; then
    if ! perr=$(hub_git "$repo" push 2>&1); then
      hub_log "$t" "push failed"
      echo "push failed: $perr" >&2
      exit 1
    fi
  fi
  return 0
}
