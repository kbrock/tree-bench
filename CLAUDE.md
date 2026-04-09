# tree-bench

Performance benchmarks for Ruby tree/hierarchy gems.

## Goals

1. **Exercise every difference** — each format and configuration option generates different SQL. If it's different, benchmark it. If a benchmark doesn't show a difference, add a better benchmark before concluding they're equivalent.
2. **Understand tradeoffs** — different formats and options excel at different things across databases. Present best practices and best use cases for each.
3. **Find performance wins** — version-over-version benchmarks catch regressions; config comparisons reveal overhead. Distinguish gem costs from framework costs.
4. **Simplify** — provide evidence for deprecating, consolidating, or recommending formats and options. Feed findings back to gem maintainers.

## Tone

This is a comparison, not a competition. Findings should highlight areas where each
library or format excels, surface potential bugs or optimization opportunities, and
help all tree gem maintainers improve. Avoid "winner/loser" framing — use neutral
language like "ancestry uses fewer queries here" rather than "ancestry wins" or
"closure_tree loses". When one library is slower at something, frame it as an
improvement opportunity, not a weakness.

## Project Structure

- `read_bench.rb` — Read operation benchmarks (IPS, queries, rows) + includes/N+1
- `write_bench.rb` — Write operation benchmarks (build tree, insert, move, destroy)
- `compare_bench.rb` — ancestry vs closure_tree side-by-side comparison
- `sweet_sql_diff` — Compare SQL output files across versions (in benchmark-sweet gem)
- `lib/tree_bench.rb` — DB setup, config registry, suite system, tree shape builders
- `lib/ancestry_model.rb` — AncestryNode model (loaded after connect)
- `lib/closure_tree_model.rb` — ClosureTreeNode model (loaded after connect)
- `FINDINGS.md` — benchmark observations and cross-gem comparison data

## Running Benchmarks

```bash
# Compare configs (default suite when no -v given, results accumulate)
DB=pg bundle exec ruby read_bench.rb -c mp1
DB=pg bundle exec ruby read_bench.rb -c mp2
DB=pg bundle exec ruby read_bench.rb -c mp3

# Compare all configs
DB=pg bundle exec ruby read_bench.rb --all

# Compare versions (auto-selected when -v given, results accumulate)
DB=pg bundle exec ruby read_bench.rb -v v5
DB=pg bundle exec ruby read_bench.rb -v v6

# Compare SQL patterns across versions
sweet_sql_diff read_bench-v5.sql read_bench-v6.sql
```

## Output Files

Derived from `$PROGRAM_NAME`, config, and version:
- `{bench}_{suite}.json` — benchmark results (e.g., `read_bench_configs.json`)
- `{bench}-{config}-{version}.sql` — SQL patterns + EXPLAIN plans (e.g., `read_bench-mp1-current.sql`)

## Why Model Files Are Separate

`closure_tree` calls `connection` at class definition time. Models must be loaded
after `connect!`, so `setup!` does `require_relative` after establishing the connection.

## Ancestry Gem

Points to local ancestry at `../ancestry` and local benchmark-sweet at `../benchmark-sweet` (see Gemfile).

## Suite System

Suite is inferred from options: passing `-v` selects `versions`, otherwise `configs`.

- **configs** — Comparing ancestry configurations (mp1 vs mp2 vs mp3 etc.). Use `-c CONFIG`.
- **versions** — Comparing code changes over time. Use `-v VERSION`, defaults config to mp1.

Each suite uses a separate JSON file so results from different experiments don't mix.

## Config Registry

Configs are just `has_ancestry` options. Table columns are built automatically via
`build_config!` and `add_virtual_columns` — no manual table lambda needed.

- `mp1`, `mp2`, `mp3` — bare formats for cross-format comparison
- `mp3-depth` — mp3 with depth cache (shows depth column impact)
- `mp3-parent` — mp3 with parent association (shows association cost/benefit)
- `ltree`, `array` — PG-only formats

Adding a new config = adding one hash entry to `CONFIGS` in `lib/tree_bench.rb`.

## Key Design Points

- Config registry is shared across all suites
- All shapes (wide/deep/mixed) built into one table via `build_all` (~814 rows). Each shape's root/mid/leaf are selective subsets — not the whole table. This ensures postgres uses indexes instead of defaulting to seq scan.
- Don't run benchmark scripts unless asked — they take 25+ minutes with IPS
- Don't run multiple bench scripts in parallel — they share the `ancestry_nodes` table and will clobber each other
- Don't change bench scripts without asking — commented-out operations are intentional notes
- Virtual columns use `table.virtual` with stored generated SQL from ancestry's `construct_*_sql` methods
- No leaking between configs — each config calls `build_config!` once (DROP+CREATE), then all shapes build into that table
- write_bench: build tree measured as queries/rows only (one-shot, not IPS). Table is built once and reused for CRUD benchmarks.
- Association benchmarks (includes, N+1) are conditional on `reflect_on_association(:children)` — only run for parent/virt configs
- When benchmarking `has_many :children`, call `node.association(:children).reset` before each iteration to avoid AR association cache hits
- `arrange_subtree` uses `node.subtree.arrange` — realistic usage (not full-table `klass.arrange`)
- Version comparison uses `ANCESTRY_PATH` env var + git worktrees (../ancestry-v4.1.0 etc.)
- `build_config!` falls back to manual column creation for older ancestry versions without `t.ancestry`
- compare_bench.rb resets closure_tree associations for cold-access measurement. Note in output that CT caches on repeat.

## TODO (local benchmarks)

- **Benchmarks for all known SQL differences** — each format generates different SQL for depth, root_id, parent_id, descendants, children. Create benchmarks that exercise every differing code path so we can compare them, find which is better, and explore improvements (indexes, alternate SQL). Currently depth is covered; root_id and parent_id computed SQL are not exercised by any benchmark.
- **Write bench closure_tree comparison** — insert/move/destroy. CT maintains a hierarchy table on every write.
- **Ordered descendants benchmark** — where closure_tree's hierarchy table ordering shines
- **Reduce benchmark configs** — drop configs where SQL is identical and we have evidence. Keep configs where differences exist.
