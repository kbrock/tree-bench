# Tree Bench

[Results](http://thebrocks.net/tree-bench/results/) | [Charts](http://thebrocks.net/tree-bench/results/1/read_bench_configs.html) | [Source](https://github.com/kbrock/tree-bench)

Performance benchmarks for Ruby tree/hierarchy gems, primarily [ancestry](https://github.com/stefankroes/ancestry) with [closure_tree](https://github.com/ClosureTree/closure_tree) comparisons.

This started as a development tool for ancestry — testing serialization formats, catching regressions across versions, and exploring new techniques like database-generated virtual columns. The benchmarks reflect that origin: they test the operations and configurations that an ancestry maintainer thinks about, and they're shaped by that perspective.

closure_tree is included because understanding a different architecture exposes blind spots in your own. The two gems make fundamentally different tradeoffs — a single ancestry column vs a hierarchy table — and seeing where each approach excels helps both improve. ancestry leads in the scenarios tested so far, but these benchmarks were written by someone who knows ancestry's weaknesses better than closure_tree's strengths. There are almost certainly scenarios where closure_tree's architecture provides advantages that aren't well-represented here yet.

A future goal is better showcasing closure_tree's strengths — ordered traversal, write patterns, and hierarchy table advantages that the current suite doesn't exercise well. At the end of the day, both gems are Ruby libraries generating SQL. A technique one gem uses — a smarter query plan, a better caching strategy, a cleaner use of database features — can often be adopted by the other. And comparing across gems is how you tell the difference between "this approach is fundamentally slower" and "this implementation has a fixable inefficiency." When one gem does 1K i/s and the other does 100K i/s for the same operation, that gap is worth investigating regardless of which side you maintain.

Trees are tested at 2-50 nodes deep and 600-6,000 nodes wide. Most real-world hierarchies are broad and shallow — biological taxonomies go ~9 levels deep, large org charts rarely exceed 12.

## Results

- Library comparison [results](results/compare_bench.md) [src](compare_bench.rb)
- Read comparison [results](results/read_bench_configs.md) [chart](results/1/read_bench_configs.html) [src](read_bench.rb)
- Write comparison [results](results/write_bench_configs.md) [src](write_bench.rb)
- Version comparison [chart](results/1/read_bench_versions.html) [src](read_bench.rb)

Operations labeled "cached" repeat the call without resetting — showing AR association cache hits when available. Same IPS for both means no caching.

## Key Findings

- **mp3 is the recommended format** — mp2 and mp3 produce identical query plans and performance, but mp3 generates simpler SQL for virtual columns and depth calculations. mp1 requires an extra OR condition for descendants (BitmapOr vs single index scan). Fun how just adding a simple slash to a string can make such a big difference.
- **Virtual columns match physical on both reads and writes** — Rails 7.1 added support for calculated columns in the database. It looks very promising. Ancestry can use for caches with `parent: :virtual` and `cache_depth: :virtual`. Interestingly, they perform identically to their callback-maintained counterparts. The small write overhead (~5-10%) from adding columns is ActiveRecord attribute tracking, not index maintenance. Virtual columns are the simpler choice — fewer callbacks, DB-maintained consistency. It has potential for this gem and others.
- **ancestry leads on most single-node reads; closure_tree scales better on tree-wide operations** — at ~830 rows, ancestry is faster across the board. At ~7,800 rows, closure_tree pulls ahead on `arrange` and multi-node `descendants`, while ancestry still leads on single-node reads. We're expanding benchmarks to cover more areas where each library's architecture provides advantages, including ordered traversal and write-heavy workloads.
- **Depth cache earns its keep for depth-filtered queries** — `cache_depth` has negligible impact on standard operations, but `at_depth` and `to_depth` scopes go from seq scan to index scan with the depth column. If using these features, adding `cache_depth` is a great solution.

See [findings.md](findings.md) for more detailed analysis and methodology.

## Outstanding

- **Ordered descendants** — closure_tree's hierarchy table stores generation order, which should provide an advantage for ordered traversal
- **Write cost comparison** — ancestry updates a single column; closure_tree maintains a hierarchy table. Quantifying the write tradeoff across insert, move, and destroy
- **CTE-only adjacency baseline** — add [acts_as_recursive_tree](https://github.com/1and1/acts_as_recursive_tree) and [acts_as_sane_tree](https://github.com/chrisroberts/acts_as_sane_tree). Both use plain `parent_id` adjacency with `WITH RECURSIVE` for subtree queries — no extra column, no closure table, no nested set. They represent a class of solution the current bench doesn't cover, and they predate widespread CTE support so the tradeoff is now interesting on its own. Useful for answering "how much does the materialized-path column actually buy you over modern recursive CTEs?"

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
