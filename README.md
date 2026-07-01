# split-tests-by-timings

GitHub Action to split test files based on JUnit XML reports, as [`circleci tests split --split-by=timings`](https://circleci.com/docs/use-the-circleci-cli-to-split-tests/#split-by-timing-data).

## Usage

### Inputs

- `reports`
    - Path to directory where JUnit XML reports are stored.
    - e.g. `tmp/junit-xml-reports`
- `glob`
    - Glob pattern to search test files. Use this for a single test pool.
    - Optional when `globs` is set.
    - e.g. `spec/**/*_spec.rb`
- `globs`
    - Glob patterns to search test files. Use a multiline string to pass multiple test pools to `split-test`.
    - Empty lines are ignored, and leading and trailing whitespace is trimmed.
    - Optional when `glob` is set.
    - e.g.
      ```yaml
      globs: |
        spec/models/**/*_spec.rb
        spec/requests/**/*_spec.rb
      ```
- `index`
    - 0-based index of test node.
    - e.g. `0`
- `total`
    - Total count of test nodes.
    - e.g. `4`
- `working-directory`
    - Working directory to run the action.
    - optional
    - default: `.`
    - e.g. `path/to/app`
- `architecture`
    - CPU architecture for `mtsmfm/split-test` binary.
    - optional
    - default: `x86_64`
    - e.g. `aarch64`

### Outputs

- `paths`
    - Relative paths of test files in a space-separated string.
    - e.g. `spec/models/user_spec.rb spec/models/post_spec.rb`

### Example

Here is a full example that runs tests in 4 nodes.

```yaml
# .github/workflows/example.yml
on:
  push:
    branches:
      - main
  pull_request:

jobs:
  rspec:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        ci_node_index:
          - 0
          - 1
          - 2
          - 3
    steps:
      - uses: actions/checkout@v3
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - uses: dawidd6/action-download-artifact@v2
        with:
          branch: main
          name: junit-xml-reports
          path: tmp/junit-xml-reports-downloaded
        continue-on-error: true
      - uses: s4na/split-tests-by-timings@v0
        id: split-tests
        with:
          reports: tmp/junit-xml-reports-downloaded
          glob: spec/**/*_spec.rb
          index: ${{ matrix.ci_node_index }}
          total: 4
      - run : |
          bundle exec rspec \
            --format progress \
            --format RspecJunitFormatter \
            --out tmp/junit-xml-reports/junit-xml-report-${{ matrix.ci_node_index }}.xml \
            ${{ steps.split-tests.outputs.paths }}
      - if: github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@v3
        with:
          if-no-files-found: error
          name: junit-xml-reports
          path: tmp/junit-xml-reports
```

### Splitting browser and non-browser specs

Use `globs` when a test pool is better described by multiple include patterns. Each non-empty line is passed to `split-test` as a separate quoted `--tests-glob` argument, so patterns such as `*` and `**` are not expanded by the shell.

```yaml
- uses: s4na/split-tests-by-timings@v0
  id: split-browser-tests
  with:
    reports: tmp/junit-xml-reports-downloaded
    globs: |
      spec/system/**/*_spec.rb
    index: ${{ matrix.pool_index }}
    total: ${{ matrix.pool_total }}
```

```yaml
- uses: s4na/split-tests-by-timings@v0
  id: split-non-browser-tests
  with:
    reports: tmp/junit-xml-reports-downloaded
    globs: |
      spec/components/**/*_spec.rb
      spec/controllers/**/*_spec.rb
      spec/decorators/**/*_spec.rb
      spec/forms/**/*_spec.rb
      spec/helpers/**/*_spec.rb
      spec/jobs/**/*_spec.rb
      spec/lib/**/*_spec.rb
      spec/mailers/**/*_spec.rb
      spec/models/**/*_spec.rb
      spec/policies/**/*_spec.rb
      spec/queries/**/*_spec.rb
      spec/requests/**/*_spec.rb
      spec/services/**/*_spec.rb
      spec/validators/**/*_spec.rb
      spec/view_objects/**/*_spec.rb
      spec/views/**/*_spec.rb
      spec/scripts/**/*_spec.rb
      spec/constraints/**/*_spec.rb
      spec/initializers/**/*_spec.rb
    index: ${{ matrix.pool_index }}
    total: ${{ matrix.pool_total }}
```

## Acknowledgement

This action uses [mtsmfm/split-test](https://github.com/mtsmfm/split-test) as its internal implementation.
