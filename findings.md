# Benchmark Findings

Observations from benchmarking tree gems. PostgreSQL, Ruby 4.0.1, Rails 7.2, 830 nodes.

## General Observations

### Association cold-access overhead is a Rails cost

`has_many` association first-access is ~35% slower than an equivalent scope returning the same query. Both ancestry (with `parent: true`) and closure_tree pay this cost. Both benefit from caching on repeat access. This is Rails overhead, not gem-specific. A lighter-weight association or scope-with-cache in Rails would help all tree gems.

### mp1 vs mp1-parent (ancestry association cost)

Adding `parent: true` (enabling `has_many :children`, `belongs_to :parent`) costs ~5% on most operations. `arrange_subtree` drops 25% — worth investigating. The payoff: `includes(:parent)` is 16x faster than N+1 `each.parent`.

### Depth cache has negligible read/write impact

<5% difference on most operations with vs without `cache_depth: true`. Same query counts. The value is for depth-limited scope queries — not yet benchmarked.

### Version-over-version (v4.1 through master)

Query counts unchanged across all ancestry versions. IPS regressions traced to `delete_if(&:blank?)` in parse (v4.3, fixed #740) and `arrange_nodes` orphan_strategy branches (v5.0, fixed #741).

## ancestry vs closure_tree

830 nodes, cold-access (association caches reset between iterations).

### Read Operations (wide shape, IPS)

| Operation | ancestry | closure_tree | Notes |
|-----------|----------|--------------|-------|
| root? | 4,476,619 | 4,019,158 | Both pure Ruby |
| ancestor_ids | 3,234,780 | 1,496 | ancestry: pure Ruby parse. CT: must query hierarchy table |
| parent | 9,162 | 9,220 | Tie. Both 1 query |
| children | 9,979 | 6,393 | Both 1 query. Association overhead on cold access; CT caches on repeat |
| ancestors | 9,178 | 4,830 | Both 1 query. JOIN through hierarchy table is heavier than `WHERE id IN (...)` |
| descendants | 6,325 | 5,374 | Both 1 query. LIKE vs JOIN. CT may win on very deep trees |
| roots | 10,684 | 8,866 | Both 1 query |
| leaf? | 10,592 | 8,619 | Both 1 query (children exists check) |
| arrange | 318 | 407 | CT uses ordered query via hierarchy table. ancestry sorts in Ruby |

Query counts identical (1 each) except `ancestor_ids`: ancestry 0, CT 1.

### Ratios across tree shapes

| Operation | wide | deep | mixed |
|-----------|------|------|-------|
| ancestor_ids | 2162x | 491x | 2252x |
| children | 1.6x | 1.4x | 1.4x |
| ancestors | 1.9x | 1.1x | 1.8x |
| descendants | 1.2x | 1.4x | 1.6x |
| arrange | 0.8x | 0.8x | 0.8x |

`ancestors` narrows on deep trees (1.9x→1.1x) — deeper ancestor chain means `WHERE id IN (25 ids)` gets heavier while CT's hierarchy JOIN stays constant.

### Architectural differences

- **Ordered traversal** — CT's hierarchy table stores generation order. ancestry would need a position column.
- **Deep tree descendants** — JOIN vs LIKE. At extreme depth, JOINs scale better than string matching.
- **Eager loading** — CT's `ancestors`/`descendants` are `has_many :through` — `includes` works natively. ancestry's are scopes — `includes` doesn't apply (except `children` with `parent: true`).
- **Write efficiency** — ancestry: single column UPDATE. CT: hierarchy table maintenance. ancestry is structurally cheaper.
- **Storage** — ancestry: O(n) single column. CT: O(n × depth) hierarchy table rows.

### Where each can improve

**ancestry:** ancestor_ids caching (avoid re-parsing), arrange via DB-ordered query, eager loading for descendants/ancestors.

**closure_tree:** ancestor_ids caching (avoid re-querying), lighter cold-access path for associations, write overhead from hierarchy table maintenance.

## Methodology

- `compare_bench.rb` / `read_bench.rb` / `write_bench.rb` in tree-bench repository
- Cold access: associations reset before each iteration
- ancestry uses mp1 config (simplest baseline) unless noted
- Same tree shapes built in both models via shared `TreeShapes` builder
