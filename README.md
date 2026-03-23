# tree-bench

Performance benchmark suite for the [ancestry](https://github.com/stefankroes/ancestry) gem.

## Setup

Requires a local checkout of `ancestry` and `benchmark-sweet` as siblings (see Gemfile).

```bash
bundle install
```

## Running Benchmarks

```bash
# Compare configs (default suite, results accumulate across runs)
DB=pg bundle exec ruby read_bench.rb -c mp1
DB=pg bundle exec ruby read_bench.rb -c mp2

# Run all configs at once
DB=pg bundle exec ruby read_bench.rb --all

# Write benchmarks (same flags)
DB=pg bundle exec ruby write_bench.rb --all

# Compare versions (switches to versions suite)
DB=pg bundle exec ruby read_bench.rb -v v5
DB=pg bundle exec ruby read_bench.rb -v v6

# Compare SQL patterns
ruby sql_diff.rb read_bench-mp1-current.sql read_bench-mp2-current.sql
```

### Options

| Flag | Description |
|------|-------------|
| `-c CONFIG` | Run a single config (default: mp1) |
| `-v VERSION` | Version label; switches to `versions` suite |
| `--all` | Run all configs (filters by DB compatibility) |
| `--force` | Re-run even if results exist |
| `--metrics M` | Comma-separated: queries,rows,ips (default: all) |

### Configs

- `mp1`, `mp2`, `mp3` — base materialized path formats
- `mp1-parent`, `mp2-parent`, `mp3-parent` — with physical parent column
- `mp1-parent-root`, `mp2-parent-root`, `mp3-parent-root` — with physical parent + root columns
- `mp1-virt`, `mp2-virt`, `mp3-virt` — with virtual (stored generated) parent + root columns
- `ltree`, `array` — PG-only formats

## Output Files

- `{bench}_{suite}.json` — benchmark results (e.g., `read_bench_configs.json`)
- `{bench}-{config}-{version}.sql` — SQL + EXPLAIN plans (e.g., `read_bench-mp1-current.sql`)

## Database

Set `DB=pg` for PostgreSQL (default: sqlite). MySQL supported via `DB=mysql`.
