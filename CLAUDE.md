# tree-bench

Performance benchmark suite for the ancestry gem.

## Project Structure

- `bench/read_bench.rb` — Read operation benchmarks (IPS, queries, rows)
- `bench/write_bench.rb` — Write operation benchmarks (insert, move, destroy)
- `bench/sql_compare.rb` — SQL capture tool (dumps actual SQL per operation)
- `lib/tree_bench.rb` — DB setup, table creation, tree shape builders
- `lib/tree_bench/ancestry_model.rb` — AncestryNode model (loaded after connect)
- `lib/tree_bench/closure_tree_model.rb` — ClosureTreeNode model (loaded after connect)
- `results/` — JSON benchmark results (accumulate across runs via benchmark-sweet)

## Running Benchmarks

```bash
TAG=mytag DB=sqlite bundle exec ruby bench/read_bench.rb
TAG=mytag DB=sqlite bundle exec ruby bench/write_bench.rb
DB=sqlite bundle exec ruby bench/sql_compare.rb
```

## Why Model Files Are Separate

`closure_tree` calls `connection` at class definition time. Models must be loaded
after `connect!`, so `setup!` does `require_relative` after establishing the connection.

## Ancestry Gem

Points to local ancestry at `../ancestry` (see Gemfile). This is the primary gem under optimization.

## Planned: Suite + Config System

The current bench scripts hardcode one ancestry configuration (mp1, cache_depth: true).
We want to compare different configurations (mp1 vs mp2, parent cache vs virtual, etc.)
and different code versions, without results from different experiments mixing together.

### Suites

A suite is "a question you're trying to answer." It determines the output file,
`compare_by`, and `report_with` axes. Defined as a case block in the bench script:

```ruby
case suite
when "configs"
  # Comparing ancestry configurations (mp1 vs mp2 vs parent cache etc.)
  # CONFIG is required, TAG optional
  x.save_file "results/config_read.json"
  x.compare_by :config, :shape, :operation
  x.report_with row: :operation, column: :config
when "versions"
  # Comparing code changes over time
  # TAG is required, CONFIG defaults to mp1
  x.save_file "results/version_read.json"
  x.compare_by :version, :shape, :operation
  x.report_with row: :operation, column: :version
end
```

Each suite uses a **separate JSON file** so results from different experiments
don't pollute each other. The suite validates required params and warns on unexpected ones.

### Config Registry

Maps config names to table schema + has_ancestry options:

```ruby
CONFIGS = {
  "mp1"            => { ancestry: { cache_depth: true } },
  "mp2"            => { ancestry: { cache_depth: true, ancestry_format: :materialized_path2 } },
  "mp1-parent"     => { ancestry: { cache_depth: true, parent: true } },
  "mp1-parent-virt"=> { ancestry: { cache_depth: true, parent: :virtual } },
}
```

The config drives table creation (column type, nullability, indexes) and
`has_ancestry` options. Adding a new config = adding one hash entry.

### Shapes

Shapes (wide/deep/mixed) are always iterated internally — they're test fixtures,
not a variable you compare. Each shape exercises different performance characteristics.

### Key Design Points

- Separate JSON files per suite prevents stale/mixed data in reports
- Suite case block is shared between read_bench and write_bench
- Config registry is shared across all suites and sql_compare
- Shapes iterate internally, other dimensions come from env/CLI args
- Use getopts for CLI — validate required params, warn on unexpected ones
