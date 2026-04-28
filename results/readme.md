# Benchmark Results

[Source](https://github.com/kbrock/tree-bench)

PostgreSQL, Ruby 4.0.1, Rails 7.2. Trees tested at 2-50 nodes deep and 600-6,000 nodes wide.

## Read Comparison

How do `ancestry` formats and options affect read performance?

[chart](1/read_bench_configs.html) | [table](1/read_bench_configs_table.html) | [raw](read_bench_configs.md)

The chart compares a subset of key configs (`mp1`, `mp3`, `mp3-parent`, `ltree`, `array`) normalized to `mp3`. The table shows all configs normalized to `mp1`. Look at `descendants` for the mp1 OR penalty, `at_depth` for the depth cache impact, and `each.parent` vs `includes(:parent)` for the N+1 story.

## Version Comparison

Is `ancestry` getting faster over time?

[chart](1/read_bench_versions.html) | [table](1/read_bench_versions_table.html) | [raw](read_bench_versions.md)

Performance from `v4.1.0` through `master`, normalized to `v5.0.0`. Look at `ancestor_ids` (2-11x faster), `arrange_subtree` (improved in recent versions), and `has_parent?` (pure Ruby, no DB).

## Library Comparison

How does `ancestry` compare to `closure_tree`?

[table](1/compare_bench.html) | [raw](compare_bench.md)

Three configurations: `ancestry` (scopes only), `ancestry+assoc` (with virtual `parent_id`), and `closure_tree` (hierarchy table). Normalized to `ancestry`. Look at `parent cached` and `children cached` for the caching architecture difference, and `ancestors`/`descendants` for the query strategy difference (LIKE vs hierarchy JOIN).

## Write Comparison

How do write operations vary across configs?

[table](1/write_bench_configs.html) | [raw](write_bench_configs.md)

`create+destroy`, `move subtree`, `parent=`, `parent_id=` across configs. Normalized to `mp1`.

## Key Findings

- **`mp3` is the recommended format.** `mp2` and `mp3` produce identical query plans and performance, but `mp3` generates simpler SQL for virtual columns and depth calculations. `mp1` requires an extra `OR` for descendants (`BitmapOr` vs single index scan).
- **Virtual columns match physical on both reads and writes.** `parent: :virtual` and `cache_depth: :virtual` (Rails 7.1 stored generated columns) perform identically to their callback-maintained counterparts. The ~5-10% write overhead is ActiveRecord attribute tracking, not index maintenance. Virtual columns are the simpler choice: fewer callbacks, DB-maintained consistency.
- **Depth cache earns its keep for depth-filtered queries.** `cache_depth` has negligible impact on standard operations, but `at_depth` and `to_depth` scopes go from seq scan to index scan with the depth column.
- **`ancestry` leads on single-node reads; `closure_tree` scales better on tree-wide operations.** At ~830 rows, `ancestry` is faster across the board. At ~7,800 rows, `closure_tree` pulls ahead on `arrange` and multi-node `descendants`.

See [findings.md](../findings.md) for detailed analysis and methodology.

## Configurations

### `mp1`

```ruby
has_ancestry
```

The default. Descendant queries require an `OR` that the other formats avoid. Included as a baseline and for legacy users.

### `mp2`

```ruby
has_ancestry format: :materialized_path2
```

Adds a trailing slash, removing the `OR` from descendant queries. Same performance as `mp3`.

### `mp3`

```ruby
has_ancestry format: :materialized_path3
```

Also removes the `OR`. Generates simpler SQL for virtual columns and depth. Simpler Ruby parsing. Recommended for new projects.

### `mp3-depth`

```ruby
has_ancestry format: :materialized_path3, cache_depth: true
```

Adds a `depth` column so the database can filter by depth directly instead of calculating it from the ancestry string. No impact on standard operations. Worth adding if you use `at_depth` or `to_depth`.

### `mp3-parent`

```ruby
has_ancestry format: :materialized_path3, cache_depth: true, parent: true
```

Adds a `parent_id` column, enabling `belongs_to :parent` and `has_many :children` associations. This unlocks `includes(:parent)` and `includes(:children)` for eager loading. See `each.parent` vs `includes(:parent)` in the read table for the N+1 difference.

### `mp3-virt`

```ruby
has_ancestry format: :materialized_path3, cache_depth: :virtual, parent: :virtual
```

Same columns and associations as `mp3-parent`, but the database maintains them automatically via stored generated columns (Rails 7.1). No callbacks needed. Identical performance.

### `ltree`

```ruby
has_ancestry format: :ltree, cache_depth: true
```

PostgreSQL-only. Uses the native `ltree` type. The database handles path operations natively instead of string manipulation.

### `array`

```ruby
has_ancestry format: :array, cache_depth: true
```

PostgreSQL-only. Stores ancestry as an integer array. Fast `ancestor_ids` (no parsing). Slower on `descendants` and `arrange`.
