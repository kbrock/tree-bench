# Benchmark Findings

Observations from benchmarking tree gems. PostgreSQL, Ruby 4.0.1, Rails 7.2. Scale 1 (~830 nodes), scale 10 (~7,800 nodes).

## General Observations

### Association cold-access overhead is a Rails cost

`has_many` association first-access is ~35% slower than an equivalent scope returning the same query. Both ancestry (with `parent: true`) and closure_tree pay this cost. Both benefit from caching on repeat access. This is Rails overhead, not gem-specific. A lighter-weight association or scope-with-cache in Rails would help all tree gems.

### mp1 vs mp1-parent (ancestry association cost)

Adding `parent: true` (enabling `has_many :children`, `belongs_to :parent`) costs ~5% on most operations. `arrange_subtree` drops 25% — worth investigating. The payoff: `includes(:parent)` is 16x faster than N+1 `each.parent`.

### Depth cache has negligible read/write impact

<5% difference on most operations with vs without `cache_depth: true`. Same query counts. Depth-limited scope benchmarks (e.g., "all nodes at depth 3") are not yet tested — that's the intended use case for this feature. If depth-limited queries don't benefit either, `cache_depth` may be a candidate for deprecation.

### Version-over-version (v4.1 through master)

Query counts unchanged across all ancestry versions. IPS regressions traced to `delete_if(&:blank?)` in parse (v4.3, fixed #740) and `arrange_nodes` orphan_strategy branches (v5.0, fixed #741).

## ancestry vs closure_tree

830 nodes, three configurations:
- **ancestry** — mp3 format, scope-based (no AR associations)
- **ancestry+assoc** — mp3 with virtual parent_id, enabling `has_many :children` / `belongs_to :parent`
- **closure_tree** — hierarchy table with AR associations

Cold access: association caches reset between iterations.

### Caching behavior

| Operation | ancestry | ancestry+assoc | closure_tree |
|-----------|----------|----------------|--------------|
| ancestor_ids (uncached) | 3.1M i/s (parse string) | 3.1M i/s | 1.2K i/s (queries hierarchy table) |
| ancestor_ids (cached) | 38M i/s (ivar) | 38M i/s | 1.2K i/s (no ivar cache, re-queries) |
| children (cached) | n/a (scope, no cache) | 3.3M i/s (AR assoc cache) | 3.3M i/s (AR assoc cache) |
| descendants (cached) | re-queries | re-queries | re-queries |

ancestry's `ancestor_ids` ivar cache is a significant advantage for code paths that call it repeatedly (e.g., `parent_id`, `root_id`, `depth` all call `ancestor_ids`). closure_tree could benefit from similar caching.

Descendants are not cached by either library — both return fresh relations on every call.

### Multi-node operations (preloading)

| Operation | ancestry | ancestry+assoc | closure_tree |
|-----------|----------|----------------|--------------|
| 4.preload(:children) | n/a (no assoc) | 2 queries | 2 queries |
| 4.descendants | 5 queries | 5 queries | 2-4 queries |

closure_tree's `self_and_descendants` association enables fewer queries when loading descendants for multiple nodes. However, `preload(:self_and_descendants)` currently errors with a SQL generation issue — an opportunity for closure_tree to fix and realize this advantage.

Both libraries support `preload(:children)` when associations are configured (ancestry with `parent: true`, closure_tree natively).

### Read operations (wide shape, IPS)

| Operation | ancestry | ancestry+assoc | closure_tree |
|-----------|----------|----------------|--------------|
| root? | 5.1M | 5.1M | 3.9M |
| ancestor_ids | 3.1M | 3.1M | 1.3K |
| parent | 10.0K | 10.0K | 9.3K |
| children | 9.2K | 8.8K | 6.4K |
| ancestors | 8.8K | 9.0K | 1.3K |
| descendants | 7.5K | 7.5K | 4.3K |
| roots | 9.4K | 9.5K | 9.0K |
| leaf? | 10.4K | 10.1K | 8.6K |
| arrange | 277 | 278 | 185 |

Query counts are identical (1 each) for most operations. The IPS differences reflect query complexity (JOIN through hierarchy table vs LIKE/IN), not query count.

### Deep trees

On deep trees (50 levels), `ancestors` narrows significantly — ancestry's `WHERE id IN (25 ids)` gets heavier while closure_tree's hierarchy JOIN stays constant. `descendants` shows a similar pattern.

### At scale (7,800 nodes)

Running with `--scale 10` (~7,800 rows vs ~830) shifts several results. Ancestry still leads on most single-node reads, but the gap narrows and closure_tree pulls ahead on tree-wide operations like `arrange` and multi-node `descendants`.

#### Wide shape (scale 10 IPS)

| Operation       | ancestry     | ancestry+assoc | closure_tree | Notes                            |
|-----------------|--------------|----------------|--------------|----------------------------------|
| ancestor_ids    | 3.1M         | 3.0M           | 5.2K         | ancestry: string parse, no query |
| parent          | 9.8K         | 9.5K           | 9.2K         |                                  |
| children        | 9.0K         | 8.5K           | 6.2K         |                                  |
| ancestors       | 8.6K         | 8.3K           | 5.2K         | changed (CT was 1.3K at s1)     |
| descendants     | 7.3K         | 7.1K           | 5.1K         | changed (CT was 4.3K at s1)     |
| roots           | 6.5K         | 6.4K           | 6.6K         | changed (ancestry led at s1)    |
| arrange         | 27.5         | 29.2           | 32.1         | changed (ancestry led at s1)    |
| 4.descendants   | 1.1K         | 1.4K           | 1.4K         |                                  |

#### Deep shape (scale 10 IPS)

| Operation       | ancestry     | ancestry+assoc | closure_tree | Notes                            |
|-----------------|--------------|----------------|--------------|----------------------------------|
| children        | 8.1K         | 7.2K           | 5.2K         |                                  |
| ancestors       | 4.5K         | 2.2K           | 1.6K         | all slower — deep IN/JOIN cost   |
| descendants     | 1.9K         | 1.8K           | 397          |                                  |
| arrange         | 28.2         | 28.0           | 32.9         | changed (ancestry led at s1)    |
| 4.descendants   | 312          | 576            | 661          | changed (ancestry led at s1)    |

#### What changed at scale

- **`arrange`** — closure_tree's hierarchy JOIN is more efficient for full-table arrange at 7,800 rows.
- **`roots`** — at 830 rows ancestry led; at 7,800 both return ~6.5K i/s.
- **`4.descendants`** — closure_tree's association-based preloading matches or beats ancestry's 5-query approach.
- **CT `ancestors`** — 1.3K → 5.2K i/s on wide. The hierarchy table JOIN benefits from larger table statistics and better query plans.
- **Deep descendants** — at 50 levels, ancestry's LIKE is still 5x faster than CT's hierarchy JOIN.
- **Build time** — ancestry: 2.6s, closure_tree: 8.9s (3.4x slower due to hierarchy table maintenance).

### Architectural differences

- **Ordered traversal** — closure_tree's hierarchy table stores generation order. ancestry would need a position column.
- **Deep tree scaling** — JOIN vs LIKE. At 50 levels, ancestry's LIKE is still faster. JOINs may scale better at extreme depth, but this hasn't been demonstrated.
- **Eager loading** — closure_tree's `ancestors`/`descendants` are `has_many :through` — `preload` could work natively (once the SQL generation bug is fixed). ancestry's are scopes — `preload` doesn't apply (except `children` with `parent: true`).
- **Write efficiency** — ancestry: single column UPDATE. closure_tree: hierarchy table maintenance. ancestry is structurally cheaper for writes.
- **Storage** — ancestry: O(n) single column. closure_tree: O(n × depth) hierarchy table rows.

### Where each can improve

**ancestry:** eager loading for descendants/ancestors (would need a descendants association or scope-preloader), arrange via DB-ordered query.

**closure_tree:** ancestor_ids caching (ivar cache would avoid re-querying hierarchy table), fix `preload(:self_and_descendants)` SQL generation, lighter cold-access path for associations.

## Methodology

- `read_bench.rb` / `write_bench.rb` / `compare_bench.rb` in tree-bench repository
- Cold access: associations reset before each iteration
- ancestry uses mp3 config with virtual parent_id for compare_bench
- Same tree shapes built in both models via shared `TreeShapes` builder
- Results: [results/](results/)
