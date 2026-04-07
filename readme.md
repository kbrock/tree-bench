# tree-bench

Benchmarks for Ruby tree gems — ancestry and closure_tree. Compares serialization formats, configuration options, and cross-library tradeoffs.

## Goals

1. **Exercise every difference** — each format and config option generates different SQL. If it's different, benchmark it. If a benchmark doesn't show a difference, add a better benchmark before concluding they're equivalent.
2. **Understand tradeoffs** — different formats and options excel at different things across databases. Present best practices and best use cases for each.
3. **Find performance wins** — version-over-version benchmarks catch regressions; config comparisons reveal overhead. Distinguish gem costs from framework costs.
4. **Simplify** — provide evidence for deprecating, consolidating, or recommending formats and options. Feed findings back to gem maintainers.

## Results

See [results/](results/) for benchmark data and [findings](findings.md) for analysis.

## Scripts

**[read_bench.rb](read_bench.rb)** — ancestry read operations (descendants, ancestors, children, arrange, depth scopes). Compare formats and config options.

```bash
DB=pg bundle exec ruby read_bench.rb -c mp3 --scale 10
DB=pg bundle exec ruby read_bench.rb --all
```

**[write_bench.rb](write_bench.rb)** — ancestry write operations (create, destroy, move).

```bash
DB=pg bundle exec ruby write_bench.rb -c mp3
DB=mysql bundle exec ruby write_bench.rb -c mp3-parent
```

**[compare_bench.rb](compare_bench.rb)** — ancestry vs closure_tree side-by-side on shared operations.

```bash
DB=pg bundle exec ruby compare_bench.rb --scale 10
```

**sweet_sql_diff** (from [benchmark-sweet](https://github.com/kbrock/benchmark-sweet)) — diff SQL output files to see what changed between configs or versions.

```bash
sweet_sql_diff results/1/read_bench-mp2-current.sql results/1/read_bench-mp3-current.sql
```

## Setup

Requires local checkouts of [ancestry](https://github.com/stefankroes/ancestry) and [benchmark-sweet](https://github.com/kbrock/benchmark-sweet) as sibling directories.

```bash
bundle install
```

Use `--help` on any script for options.

### Configs

| Config           | Purpose                                    |
|------------------|--------------------------------------------|
| mp1, mp2, mp3    | Bare formats for cross-format comparison   |
| mp3-depth        | mp3 + depth cache column                   |
| mp3-parent       | mp3 + parent association                   |
| mp3-parent-root  | mp3 + parent and root associations         |
| ltree, array     | PostgreSQL-only formats                    |

### Output

Each run produces JSON (benchmark data) and SQL (queries + EXPLAIN plans) in `results/{scale}/`.
