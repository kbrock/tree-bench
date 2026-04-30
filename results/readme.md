# Benchmark Results

[Source](https://github.com/kbrock/tree-bench)

PostgreSQL, Ruby 4.0.1, Rails 7.2. Trees tested at 2-50 nodes deep and 600-6,000 nodes wide.

## Read Comparison

How do `ancestry` formats and options affect read performance?

[chart](1/read_bench_configs.html) | [table](1/read_bench_configs_table.html) | [raw](read_bench_configs.md)

All configs normalized to `mp1`. Look at `descendants` for the `mp1` OR penalty, `at_depth` for the depth cache impact, and `each.parent` vs `includes(:parent)` for the N+1 story.

## Version Comparison

Is `ancestry` getting faster over time?

[chart](1/read_bench_versions.html) | [table](1/read_bench_versions_table.html) | [raw](read_bench_versions.md)

Performance from `v4.1.0` through `master`, normalized to `v5.0.0`. Look at `ancestor_ids` (`2`-`11x` faster), `arrange_subtree` (improved in recent versions), and `has_parent?` (pure Ruby, no DB).

## Library Comparison

How does `ancestry` compare to `closure_tree`?

[table](1/compare_bench.html) | [raw](compare_bench.md)

Two `ancestry` configurations (`mp3` and `mp3-virt`, which adds a `parent_id` for eager loading) and `closure_tree` (`ct`). Normalized to `mp3`. Look at `parent cached` and `children cached` for the caching architecture difference, and `ancestors`/`descendants` for the query strategy difference.

## Write Comparison

How do write operations vary across configs?

[table](1/write_bench_configs.html) | [raw](write_bench_configs.md)

`create+destroy`, `move subtree`, `parent=`, `parent_id=` across configs. Normalized to `mp1`.

See [findings.md](../findings.md) for detailed analysis and methodology.

## Configurations

### `mp1` (materialized_path)

```ruby
has_ancestry
```

The default. Descendant queries require an `OR` that the other formats avoid. Included as a baseline and for legacy users.

### `mp2` (materialized_path2)

```ruby
has_ancestry format: :materialized_path2
```

Adds a trailing slash, removing the `OR` from descendant queries. Same performance as `mp3`. Superseded by `mp3`, which generates simpler SQL and simpler Ruby parsing.

### `mp3` (materialized_path3)

```ruby
has_ancestry format: :materialized_path3
```

Also removes the `OR`. Generates simpler SQL for virtual columns and depth. Simpler Ruby parsing. **Recommended for new projects.**

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

PostgreSQL-only. Uses the native `ltree` type. The database handles path operations natively instead of string manipulation. **Recommended for new PostgreSQL projects.**

### `array`

```ruby
has_ancestry format: :array, cache_depth: true
```

PostgreSQL-only. Stores ancestry as an integer array. Fast `ancestor_ids` (no parsing). Slower on `descendants` and `arrange` due to a known index issue being fixed. **Experimental.**

### `ct` (closure_tree gem)

```ruby
gem "closure_tree"
```

From the [`closure_tree`](https://github.com/ClosureTree/closure_tree) gem. Uses a separate hierarchy table with `ancestor_id`/`descendant_id` pairs. `belongs_to :parent` and `has_many :children` are built in. Used in the library comparison benchmarks.
