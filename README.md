# tree-bench

Performance benchmarks for Ruby tree/hierarchy gems.

## Goals

1. **Find low-hanging fruit** — identify hot paths and operations where small code changes yield big wins, across any tree gem.
2. **Compare serialization formats** — materialized path (mp1/mp2/mp3), ltree, array, closure table. Which formats are genuinely faster, and for which operations?
3. **Measure enhancement impact** — do features like caching `parent_id`, `root_id`, or `depth` actually pay off? Or is the overhead not worth it?
4. **Cross-library, cross-database comparison** — ancestry, closure_tree, and others. PostgreSQL, MySQL, SQLite. Some performance insights are universal (e.g., association cold-access overhead is a Rails cost, not gem-specific), and benchmarks should surface those.

## Benchmarks

### `read_bench.rb` — configs suite

Compares serialization formats and enhancements within the same ancestry version. Answers: **is there a format that wins? Does caching parent_id or root_id actually help?**

```bash
DB=pg bundle exec ruby read_bench.rb --all
```

Outputs IPS, query counts, and SQL + EXPLAIN plans per config. Run individual configs with `-c mp3`.

### `read_bench.rb` — versions suite

Compares the same config across ancestry versions. Answers: **did we introduce extra queries, slower Ruby processing, or regressions?**

Uses mp1 as the default config since it exists in all versions. The format itself doesn't matter — the point is detecting changes in code paths between releases.

```bash
DB=pg bundle exec ruby read_bench.rb -v v4.1
DB=pg bundle exec ruby read_bench.rb -v v5
DB=pg bundle exec ruby read_bench.rb -v current
```

### `write_bench.rb`

Measures insert, move, and destroy operations. Answers: **what's the write cost of each format and enhancement?**

```bash
DB=pg bundle exec ruby write_bench.rb --all
```

### `compare_bench.rb`

Side-by-side ancestry vs closure_tree on the same operations. Answers: **where does each library's architecture shine, and what SQL techniques can we learn from each other?**

```bash
DB=pg bundle exec ruby compare_bench.rb
```

### `sql_diff.rb`

Diffs SQL output files to see exactly what changed between versions or configs.

```bash
ruby sql_diff.rb read_bench-mp1-v5.sql read_bench-mp1-current.sql
```

## Findings

See [FINDINGS.md](FINDINGS.md) for benchmark observations and cross-gem comparison data.

## Setup

Requires local checkouts of [ancestry](https://github.com/stefankroes/ancestry) and [benchmark-sweet](https://github.com/kbrock/benchmark-sweet) as sibling directories.

```bash
bundle install
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

### Output Files

- `{bench}_{suite}.json` — benchmark results (e.g., `read_bench_configs.json`)
- `{bench}-{config}-{version}.sql` — SQL + EXPLAIN plans (e.g., `read_bench-mp1-current.sql`)

### Database

Set `DB=pg` for PostgreSQL (default: sqlite). MySQL supported via `DB=mysql`.

## Methodology

- 830-node trees in three shapes: wide (flat), deep (chain), mixed (realistic)
- All shapes built into one table so PostgreSQL uses indexes realistically
- Cold access: association caches reset between iterations
- Mid-level nodes used for descendant queries (avoids whole-table seq scan on root)
- IPS via benchmark-ips, query/row counts via ActiveSupport instrumentation
