#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
script="$project_dir/scripts/draw-commits.sh"
test_dir=$(mktemp -d "${TMPDIR:-/tmp}/drawcommitmosaic-test.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT
export HOME="$test_dir/home"
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_AUTHOR_DATE GIT_COMMITTER_DATE
unset GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
mkdir -p "$HOME" "$test_dir/bin" "$test_dir/empty-template"

# Any accidental network command fails the test, even if its exit is ignored.
export TEST_REAL_GIT
TEST_REAL_GIT=$(command -v git)
export TEST_NETWORK_MARKER="$test_dir/network-used"
cat > "$test_dir/bin/git" << 'STUB'
#!/usr/bin/env bash
for argument in "$@"; do
  if [[ "$argument" == status && "${TEST_FAIL_STATUS:-0}" == 1 ]]; then exit 98; fi
  case "$argument" in
    pull | push | fetch)
      printf '%s\n' "$argument" >"$TEST_NETWORK_MARKER"
      exit 97
      ;;
  esac
done
exec "$TEST_REAL_GIT" "$@"
STUB
chmod +x "$test_dir/bin/git"
export PATH="$test_dir/bin:$PATH"

passed=0
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}
pass() {
  passed=$((passed + 1))
  printf 'PASS: %s\n' "$*"
}
assert_equal() { [[ "$1" == "$2" ]] || fail "$3 (expected: $1; actual: $2)"; }
expect_failure() {
  if "$@" > "$test_dir/output" 2>&1; then fail 'command unexpectedly succeeded'; fi
}
new_repo() {
  git init --quiet --template="$test_dir/empty-template" "$1"
  git -C "$1" config user.name 'Mosaic Test'
  git -C "$1" config user.email test@example.invalid
  git -C "$1" config commit.gpgsign false
}

repo="$test_dir/repo with spaces"
new_repo "$repo"
printf 'seed\n' > "$repo/tracked.txt"
git -C "$repo" add tracked.txt
git -C "$repo" commit --quiet -m initial
initial=$(git -C "$repo" rev-parse HEAD)
initial_tree=$(git -C "$repo" rev-parse 'HEAD^{tree}')
date=2026-01-04T12:00:00+08:00

bash "$script" --help > /dev/null
expect_failure bash "$script"
expect_failure bash "$script" --unknown
expect_failure bash "$script" --repo
expect_failure bash "$script" --message
expect_failure bash "$script" --dates-file
pass 'help and invalid arguments'

bash "$script" --repo "$repo" "$date" > "$test_dir/output"
grep -q '^PREVIEW ' "$test_dir/output"
assert_equal "$initial" "$(git -C "$repo" rev-parse HEAD)" 'preview changed HEAD'
assert_equal '' "$(git -C "$repo" status --porcelain)" 'preview changed files'
pass 'default preview is read-only; target path may contain spaces'

expect_failure bash "$script" --repo "$repo" --apply not-a-date
expect_failure bash "$script" --repo "$test_dir" "$date"
assert_equal "$initial" "$(git -C "$repo" rev-parse HEAD)" 'invalid input changed HEAD'
pass 'invalid dates and non-repositories are rejected'

bash "$script" --repo "$repo" --apply "$date" > /dev/null
assert_equal "$date|$date" "$(git -C "$repo" log -1 --format='%aI|%cI')" 'commit dates differ'
assert_equal "$initial_tree" "$(git -C "$repo" rev-parse 'HEAD^{tree}')" 'empty commit changed content'
assert_equal "$initial" "$(git -C "$repo" rev-parse 'HEAD^')" 'existing commit was rewritten'
pass 'apply creates an empty commit with matching author/committer dates and preserves history'

message="literal \$(touch $test_dir/unexpected)"
bash "$script" --repo "$repo" --apply --message "$message" "$date" > /dev/null
assert_equal "$message" "$(git -C "$repo" log -1 --format=%B)" 'custom message changed'
[[ ! -e "$test_dir/unexpected" ]] || fail 'message was executed'
pass 'custom messages are treated as literal text'

before=$(git -C "$repo" rev-parse HEAD)
printf 'unstaged\n' > "$repo/tracked.txt"
expect_failure bash "$script" --repo "$repo" --apply "$date"
assert_equal 'unstaged' "$(cat "$repo/tracked.txt")" 'unstaged file changed'
printf 'seed\n' > "$repo/tracked.txt"
printf 'untracked\n' > "$repo/other.txt"
expect_failure bash "$script" --repo "$repo" --apply "$date"
git -C "$repo" add other.txt
index=$(git -C "$repo" write-tree)
bash "$script" --repo "$repo" "$date" > /dev/null
expect_failure bash "$script" --repo "$repo" --apply "$date"
assert_equal "$index" "$(git -C "$repo" write-tree)" 'staged changes were modified'
assert_equal "$before" "$(git -C "$repo" rev-parse HEAD)" 'dirty tree changed HEAD'
git -C "$repo" reset --quiet HEAD -- other.txt
rm -- "$repo/other.txt"
pass 'unstaged, untracked and staged files are preserved; apply rejects a dirty tree'

before=$(git -C "$repo" rev-parse HEAD)
expect_failure env TEST_FAIL_STATUS=1 bash "$script" --repo "$repo" --apply "$date"
assert_equal "$before" "$(git -C "$repo" rev-parse HEAD)" 'failed status check allowed a commit'
pass 'failure to read working tree status cannot be treated as a clean tree'

printf '# dates\r\n\r\n%s\r\n%s' "$date" '2026-01-05T12:00:00+08:00' > "$test_dir/dates"
count=$(git -C "$repo" rev-list --count HEAD)
bash "$script" --repo "$repo" --apply --dates-file "$test_dir/dates" > /dev/null
assert_equal "$((count + 2))" "$(git -C "$repo" rev-list --count HEAD)" 'batch count differs'
assert_equal '2026-01-05T12:00:00+08:00' "$(git -C "$repo" log -1 --format=%aI)" 'last date missing'
pass 'dates files support comments, blank lines, CRLF and a missing final newline'

before=$(git -C "$repo" rev-parse HEAD)
printf '%s\nnot-a-date\n' "$date" > "$test_dir/invalid-dates"
expect_failure bash "$script" --repo "$repo" --apply --dates-file "$test_dir/invalid-dates"
expect_failure bash "$script" --repo "$repo" --dates-file "$test_dir/dates" "$date"
expect_failure bash "$script" --repo "$repo" --dates-file "$test_dir/missing"
printf '# no dates\n' > "$test_dir/empty"
expect_failure bash "$script" --repo "$repo" --dates-file "$test_dir/empty"
assert_equal "$before" "$(git -C "$repo" rev-parse HEAD)" 'invalid batch created a partial history'
pass 'the entire batch is validated before writing'

(
  cd "$test_dir"
  bash "$project_dir/drawHeart.sh" --repo "$repo" > "$test_dir/output"
  grep -q '^Commits: 18$' "$test_dir/output"
  bash "$project_dir/shellpullpush.sh" --repo "$repo" 'Nov 10 23:04:57 2019 -0700' > /dev/null
)
assert_equal "$before" "$(git -C "$repo" rev-parse HEAD)" 'legacy entry changed HEAD during preview'
count=$(git -C "$repo" rev-list --count HEAD)
bash "$project_dir/drawHeart.sh" --repo "$repo" --apply > /dev/null
assert_equal "$((count + 18))" "$(git -C "$repo" rev-list --count HEAD)" 'heart batch count differs'
assert_equal "$initial_tree" "$(git -C "$repo" rev-parse 'HEAD^{tree}')" 'heart changed tracked content'
pass 'both legacy entry points work from another directory; heart applies all 18 dates'

branch=$(git -C "$repo" symbolic-ref --short HEAD)
git -C "$repo" checkout --quiet --detach
before=$(git -C "$repo" rev-parse HEAD)
expect_failure bash "$script" --repo "$repo" --apply "$date"
assert_equal "$before" "$(git -C "$repo" rev-parse HEAD)" 'detached HEAD changed'
git -C "$repo" checkout --quiet "$branch"
pass 'detached HEAD cannot receive generated commits'

new_repo "$test_dir/new"
bash "$script" --repo "$test_dir/new" --apply "$date" > /dev/null
assert_equal 1 "$(git -C "$test_dir/new" rev-list --count HEAD)" 'unborn branch failed'
assert_equal '' "$(git -C "$test_dir/new" ls-tree --name-only HEAD)" 'initial commit is not empty'
pass 'a newly initialized repository is supported'

git init --quiet --template="$test_dir/empty-template" "$test_dir/no-identity"
bash "$script" --repo "$test_dir/no-identity" "$date" > /dev/null
expect_failure bash "$script" --repo "$test_dir/no-identity" --apply "$date"
pass 'preview needs no identity; apply requires an identity'

mkdir -p "$test_dir/hooks"
printf '#!/bin/sh\nexit 1\n' > "$test_dir/hooks/pre-commit"
chmod +x "$test_dir/hooks/pre-commit"
git -C "$repo" config core.hooksPath "$test_dir/hooks"
before=$(git -C "$repo" rev-parse HEAD)
expect_failure bash "$script" --repo "$repo" --apply "$date" "$date"
assert_equal "$before" "$(git -C "$repo" rev-parse HEAD)" 'commit hook was bypassed'
pass 'user commit hooks are respected; a rejected commit stops the batch'

[[ ! -e "$TEST_NETWORK_MARKER" ]] || fail 'a Git network command was invoked'
pass 'no pull, push or fetch was invoked'
printf '\nAll %s checks passed.\n' "$passed"
