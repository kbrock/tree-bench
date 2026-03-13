# tree-bench

Performance benchmark suite for the ancestry gem.

## Project Structure

- `read_bench.rb` — Read operation benchmarks (IPS, queries, rows)
- `write_bench.rb` — Write operation benchmarks (insert, move, destroy)
- `descendant_bench.rb` — Descendant-focused benchmarks
- `sql_diff.rb` — Compare SQL output files across versions
- `lib/tree_bench.rb` — DB setup, config registry, suite system, tree shape builders
- `lib/ancestry_model.rb` — AncestryNode model (loaded after connect)
- `lib/closure_tree_model.rb` — ClosureTreeNode model (loaded after connect)

## Running Benchmarks

```bash
# Compare configs (default suite when no -v given, results accumulate)
DB=pg bundle exec ruby read_bench.rb -c mp1
DB=pg bundle exec ruby read_bench.rb -c mp2
DB=pg bundle exec ruby read_bench.rb -c mp3

# Compare versions (auto-selected when -v given, results accumulate)
DB=pg bundle exec ruby read_bench.rb -v v5
DB=pg bundle exec ruby read_bench.rb -v v6

# Compare SQL patterns across versions
ruby sql_diff.rb read_bench-v5.sql read_bench-v6.sql
```

## Output Files

Derived from script name:
- `read_bench_versions.json` / `read_bench_configs.json` — benchmark results
- `read_bench-current.sql` / `read_bench-v6.sql` — SQL patterns + EXPLAIN plans

## Why Model Files Are Separate

`closure_tree` calls `connection` at class definition time. Models must be loaded
after `connect!`, so `setup!` does `require_relative` after establishing the connection.

## Ancestry Gem

Points to local ancestry at `../ancestry` and local benchmark-sweet at `../benchmark-sweet` (see Gemfile).

## Suite + Config System

### Suites

A suite determines `compare_by` and `report_with` axes. Defaults to `versions`.

- **configs** — Comparing ancestry configurations (mp1 vs mp2 vs mp3 etc.). Requires `-c CONFIG`.
- **versions** — Comparing code changes over time. Requires `-v VERSION`, defaults config to mp1.

Each suite uses a separate JSON file so results from different experiments don't mix.

### Config Registry

Maps config names to table schema + has_ancestry options:

- `mp1`, `mp2`, `mp3` — base configs (materialized_path, _path2, _path3)
- `mp1-parent`, `mp2-parent`, `mp3-parent` — with physical parent column
- `mp1-parent-root`, `mp2-parent-root`, `mp3-parent-root` — with physical parent + root columns
- `mp1-virt`, `mp2-virt`, `mp3-virt` — with virtual parent + root (no extra columns)

Adding a new config = adding one hash entry to `CONFIGS` in `lib/tree_bench.rb`.

### Key Design Points

- Config registry is shared across all suites
- Shapes (wide/deep/mixed) iterate internally — they're fixtures, not comparison axes
- Don't change bench scripts without asking — commented-out operations are intentional notes
