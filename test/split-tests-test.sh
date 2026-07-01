#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_equals() {
  local expected="$1"
  local actual="$2"
  local message="$3"

  if [ "$actual" != "$expected" ]; then
    printf 'not ok - %s\nexpected: %s\nactual:   %s\n' "$message" "$expected" "$actual" >&2
    exit 1
  fi
}

run_split_tests() {
  local work_dir="$1"
  shift

  (
    cd "$work_dir"
    : > github-output
    INPUT_REPORTS=reports \
      INPUT_INDEX=1 \
      INPUT_TOTAL=3 \
      GITHUB_OUTPUT="$work_dir/github-output" \
      "$@" \
      "$ROOT_DIR/scripts/split-tests"
  )
}

make_fake_work_dir() {
  local work_dir="$1"
  mkdir -p "$work_dir"
  cat > "$work_dir/split-test" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > split-test-args
printf '%s\n' "$PWD/spec/models/user_spec.rb"
SH
  chmod +x "$work_dir/split-test"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

work_dir="$tmp_dir/single-glob"
make_fake_work_dir "$work_dir"
run_split_tests "$work_dir" env INPUT_GLOB='spec/**/*_spec.rb' INPUT_GLOBS=''
assert_equals '--junit-xml-report-dir
reports
--node-index
1
--node-total
3
--tests-glob
spec/**/*_spec.rb' "$(cat "$work_dir/split-test-args")" "uses the legacy glob input"
assert_equals 'paths=spec/models/user_spec.rb ' "$(cat "$work_dir/github-output")" "writes relative space-separated paths"

work_dir="$tmp_dir/multiple-globs"
make_fake_work_dir "$work_dir"
run_split_tests "$work_dir" env INPUT_GLOB='spec/**/*_spec.rb' INPUT_GLOBS=$'  spec/system/**/*_spec.rb  \n\nspec/models/**/*_spec.rb\n'
assert_equals '--junit-xml-report-dir
reports
--node-index
1
--node-total
3
--tests-glob
spec/system/**/*_spec.rb
--tests-glob
spec/models/**/*_spec.rb' "$(cat "$work_dir/split-test-args")" "uses non-empty trimmed globs lines before glob"

work_dir="$tmp_dir/no-shell-expansion"
make_fake_work_dir "$work_dir"
mkdir -p "$work_dir/spec/system"
touch "$work_dir/spec/system/example_spec.rb"
run_split_tests "$work_dir" env INPUT_GLOB='' INPUT_GLOBS='spec/system/*_spec.rb'
assert_equals 'spec/system/*_spec.rb' "$(awk '/--tests-glob/{getline; print}' "$work_dir/split-test-args")" "passes glob patterns without shell expansion"

work_dir="$tmp_dir/missing-input"
make_fake_work_dir "$work_dir"
if run_split_tests "$work_dir" env INPUT_GLOB='' INPUT_GLOBS=$' \n\t ' 2> "$work_dir/stderr"; then
  printf 'not ok - fails when both glob and globs are empty\n' >&2
  exit 1
fi
if ! grep -q "Either the 'glob' input or at least one non-empty line in the 'globs' input is required" "$work_dir/stderr"; then
  printf 'not ok - prints a helpful missing input error\n' >&2
  cat "$work_dir/stderr" >&2
  exit 1
fi

printf 'ok - split-tests\n'
