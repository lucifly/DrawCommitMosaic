#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat << 'HELP'
Usage: draw-commits.sh [options] DATE [DATE ...]
       draw-commits.sh [options] --dates-file FILE

Create empty Git commits with matching author and committer dates.
The default is a read-only preview. No pull or push is performed.

Options:
  --repo DIR         Target working tree (default: current directory)
  --dates-file FILE  Read dates; blank lines and # comment lines are skipped
  --message TEXT     Use the same message for each commit
  --dry-run          Preview the plan (default)
  --apply            Create local commits; requires a clean, attached working tree
  -h, --help         Show this help

Example:
  ./scripts/draw-commits.sh --repo ../mosaic '2026-01-04T12:00:00+08:00'
HELP
}

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 2
}

require_value() {
  [[ $# -ge 2 && -n "$2" ]] || fail "$1 requires a value"
}

repo=.
dates_file=
message=
apply=false
dates=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      require_value "$@"
      repo=$2
      shift 2
      ;;
    --dates-file)
      require_value "$@"
      [[ -z "$dates_file" ]] || fail '--dates-file may only be specified once'
      dates_file=$2
      shift 2
      ;;
    --message)
      require_value "$@"
      message=$2
      shift 2
      ;;
    --apply)
      apply=true
      shift
      ;;
    --dry-run)
      apply=false
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      while [[ $# -gt 0 ]]; do
        dates+=("$1")
        shift
      done
      ;;
    -*) fail "unknown option: $1" ;;
    *)
      dates+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$dates_file" ]]; then
  [[ ${#dates[@]} -eq 0 ]] || fail 'use either positional dates or --dates-file'
  [[ -f "$dates_file" && -r "$dates_file" ]] || fail "cannot read dates file: $dates_file"
  while IFS= read -r line || [[ -n "$line" ]]; do
    line=${line%$'\r'}
    case "$line" in
      '' | \#*) continue ;;
    esac
    dates+=("$line")
  done < "$dates_file"
fi

[[ ${#dates[@]} -gt 0 ]] || fail 'at least one date is required; see --help'
command -v git > /dev/null 2>&1 || fail 'Git is required'
inside=$(git -C "$repo" rev-parse --is-inside-work-tree 2> /dev/null) || fail 'target is not a Git working tree'
[[ "$inside" == true ]] || fail 'target is not a Git working tree'
repo=$(git -C "$repo" rev-parse --show-toplevel)

# Validate the whole batch before any commits. Preview does not need a configured identity.
for date in "${dates[@]}"; do
  if ! GIT_AUTHOR_NAME=DrawCommitMosaic GIT_AUTHOR_EMAIL=preview@example.invalid \
    GIT_AUTHOR_DATE="$date" git -C "$repo" var GIT_AUTHOR_IDENT > /dev/null 2>&1; then
    fail "invalid Git date: $date"
  fi
done

if "$apply"; then
  git -C "$repo" symbolic-ref --quiet HEAD > /dev/null || fail 'switch to a branch before applying'
  worktree_status=$(git -C "$repo" status --porcelain --untracked-files=normal) || fail 'cannot read working tree status'
  [[ -z "$worktree_status" ]] || fail 'working tree must be clean, including staged and untracked files'
  git -C "$repo" -c user.useConfigOnly=true var GIT_AUTHOR_IDENT > /dev/null || fail 'configure your Git author identity first'
  git -C "$repo" -c user.useConfigOnly=true var GIT_COMMITTER_IDENT > /dev/null || fail 'configure your Git committer identity first'
fi

printf 'Repository: %s\n' "$repo"
printf 'Commits: %s\n' "${#dates[@]}"
for date in "${dates[@]}"; do
  commit_message=${message:-"mosaic: $date"}
  if "$apply"; then
    GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
      git -C "$repo" -c user.useConfigOnly=true commit --allow-empty --only --message="$commit_message"
  else
    printf 'PREVIEW date=%q message=%q\n' "$date" "$commit_message"
  fi
done

if "$apply"; then
  printf 'Created %s local commit(s). No pull or push was performed.\n' "${#dates[@]}"
else
  printf 'Preview only. Re-run with --apply to create local commits.\n'
fi
