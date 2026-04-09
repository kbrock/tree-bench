# tree-bench

Performance benchmarks for Ruby tree/hierarchy gems — [ancestry](https://github.com/stefankroes/ancestry) and [closure_tree](https://github.com/ClosureTree/closure_tree). Compares serialization formats, configuration options, and cross-library tradeoffs on PostgreSQL.

## Key Findings

- **mp3 is the recommended format** — mp2 and mp3 produce identical query plans and performance, but mp3 generates simpler SQL for virtual columns and depth calculations. mp1 requires an extra OR condition for descendants (BitmapOr vs single index scan).
- **Virtual columns match physical on both reads and writes** — `parent: :virtual` and `cache_depth: :virtual` (stored generated columns) perform identically to their callback-maintained counterparts. The small write overhead (~5-10%) from adding columns is ActiveRecord attribute tracking, not index maintenance. Virtual columns are the simpler choice — fewer callbacks, DB-maintained consistency.
- **ancestry leads on most single-node reads; closure_tree scales better on tree-wide operations** — at ~830 rows, ancestry is faster across the board. At ~7,800 rows, closure_tree pulls ahead on `arrange` and multi-node `descendants`, while ancestry still leads on single-node reads. We're expanding benchmarks to cover more areas where each library's architecture provides advantages, including ordered traversal and write-heavy workloads.
- **Depth cache earns its keep for depth-filtered queries** — `cache_depth` has negligible impact on standard operations, but `at_depth` and `to_depth` scopes go from seq scan to index scan with the depth column.

See [findings.md](findings.md) for detailed analysis and methodology.

## Outstanding

- **Ordered descendants** — closure_tree's hierarchy table stores generation order, which should provide an advantage for ordered traversal
- **Write cost comparison** — ancestry updates a single column; closure_tree maintains a hierarchy table. Quantifying the write tradeoff across insert, move, and destroy
- **Config reduction** — virtual and physical columns are equivalent; simplifying the benchmark matrix

## Running

Requires local checkouts of [ancestry](https://github.com/stefankroes/ancestry) and [benchmark-sweet](https://github.com/kbrock/benchmark-sweet) as sibling directories.

```bash
bundle install

# ancestry config comparison (~830 rows)
DB=pg bundle exec ruby read_bench.rb --all

# ancestry config comparison (~7,800 rows)
DB=pg bundle exec ruby read_bench.rb --all --scale 10

# ancestry vs closure_tree
DB=pg bundle exec ruby compare_bench.rb --scale 10

# ancestry write operations
DB=pg bundle exec ruby write_bench.rb --all

# insert cost by column configuration
DB=pg bundle exec ruby insert_bench.rb
```

## Results

- [Config comparison](results/read_bench_configs.md) — ancestry formats and options
- [Write comparison](results/write_bench_configs.md) — insert, move, destroy across configs
- [Insert cost](results/insert_bench_configs.md) — column overhead on writes
- [ancestry vs closure_tree](results/compare_bench.md) — side-by-side on shared operations
