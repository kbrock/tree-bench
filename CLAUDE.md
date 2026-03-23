# tree-bench

Performance benchmark suite for the ancestry gem.

## Project Structure

- `read_bench.rb` — Read operation benchmarks (IPS, queries, rows) + includes/N+1
- `write_bench.rb` — Write operation benchmarks (build tree, insert, move, destroy)
- `compare_bench.rb` — ancestry vs closure_tree side-by-side comparison
- `sql_diff.rb` — Compare SQL output files across versions
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
ruby sql_diff.rb read_bench-v5.sql read_bench-v6.sql
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

- `mp1`, `mp2`, `mp3` — base configs (materialized_path, _path2, _path3)
- `mp1-parent`, `mp2-parent`, `mp3-parent` — with physical parent column
- `mp1-parent-root`, `mp2-parent-root`, `mp3-parent-root` — with physical parent + root columns
- `mp1-virt`, `mp2-virt`, `mp3-virt` — with virtual (stored generated) parent + root columns
- `ltree`, `array` — PG-only formats

Adding a new config = adding one hash entry to `CONFIGS` in `lib/tree_bench.rb`.

## Key Design Points

- Config registry is shared across all suites
- All shapes (wide/deep/mixed) built into one table via `build_all` (~814 rows). Each shape's root/mid/leaf are selective subsets — not the whole table. This ensures postgres uses indexes instead of defaulting to seq scan.
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

- Depth-limited scope benchmarks — where `cache_depth` should shine (not yet tested)
- Write bench: replace transaction rollback with real move-back pattern (b=a.children[0]; b.update(parent: c); b.update(parent: a))
- Larger table benchmarks (10x scale) — prove whether +1 query matters at realistic sizes
- closure_tree write comparison (insert/move/destroy)
- Preload/includes benchmark — ancestry N+1 gap vs CT's `includes(:descendants)`
- mp1 vs mp1-parent IPS comparison — cost of adding associations
- GitHub usage survey — who uses ancestry, what options, what version, interesting forks
