# Benchmark Findings

Observations from benchmarking tree gems. PostgreSQL, Ruby 4.0.1, Rails 7.2. Scale 1 (~830 nodes), scale 10 (~7,800 nodes).

## General Observations

### Association cold-access overhead is a Rails cost

`has_many` association first-access is ~35% slower than an equivalent scope returning the same query. Both ancestry (with `parent: true`) and closure_tree pay this cost. Both benefit from caching on repeat access. This is Rails overhead, not gem-specific. A lighter-weight association or scope-with-cache in Rails would help all tree gems.

### mp1 vs mp1-parent (ancestry association cost)

Adding `parent: true` (enabling `has_many :children`, `belongs_to :parent`) costs ~5% on most operations. `arrange_subtree` drops 25% — worth investigating. The payoff: `includes(:parent)` is 16x faster than N+1 `each.parent`.

### Physical vs virtual cached columns

`parent: :virtual` / `cache_depth: :virtual` (stored generated columns) perform identically to their `true` (callback-maintained) counterparts on both reads and writes. Same columns, same indexes, same query plans, same IPS.

Insert benchmark (10-node chain, pg) confirmed virtual ≡ physical on writes:

| Config      | IPS (avg) |
|-------------|-----------|
| base (mp3)  |    ~3,700 |
| parent-virt |    ~3,350 |
| parent-phys |    ~3,350 |
| depth-virt  |    ~3,550 |
| depth-phys  |    ~3,450 |

The ~10% parent overhead and ~5% depth overhead persist even with indexes removed — the cost is ActiveRecord attribute tracking and callbacks, not index maintenance. Depth at root vs depth 10 shows no difference (insert cost is independent of tree depth).

### Depth cache matters for depth-limited queries

<5% difference on standard operations (descendants, ancestors, etc.) with vs without `cache_depth: true`. Same query counts. But depth-limited scopes show the real value:

Without `cache_depth` (computed from ancestry string):
- `at_depth(3)` — **Seq Scan**, computes `LENGTH(ancestry) - LENGTH(REPLACE(ancestry,'/',''))` per row
- `descendants.at_depth(+1)` — ancestry index only, computed depth as heap filter

With `cache_depth: true` (physical column + index):
- `at_depth(3)` — **Bitmap Index Scan** on `ancestry_depth` column
- `descendants.at_depth(+1)` — **BitmapAnd** combining depth index + ancestry index

At 7,800 rows, `at_depth(3)` returns 911 rows. Without the depth column, postgres scans the entire table computing depth per row. With it, it's a direct index lookup. The depth column earns its keep for any query that filters by depth — keep `cache_depth` for applications that use `at_depth`, `to_depth`, or depth-limited descendant queries.

### Virtual parent_id SQL by format

The SQL expression used to compute `parent_id` from the ancestry column varies significantly by format:

| Format | `construct_parent_id_sql` (postgres)                              |
|--------|-------------------------------------------------------------------|
| mp1    | `SUBSTR(col, LENGTH(RTRIM(col, REPLACE(col, '/', ''))) + 1)`     |
| mp2    | same, but must `RTRIM(col,'/')` first (trailing delimiter)        |
| mp3    | same as mp2                                                       |
| ltree  | `subpath(col, nlevel(col) - 1, 1)::text`                         |
| array  | `col[array_length(col, 1)]`                                       |

ltree and array have clean, native expressions. mp1/mp2/mp3 all use the same RTRIM+REPLACE+SUBSTR chain (mp1 skips one RTRIM since it has no trailing delimiter, but the difference is trivial).

### parent_id enables simpler leaves query

Current `leaves` scope: `WHERE NOT EXISTS (SELECT 1 FROM table c WHERE c.ancestry = (child_ancestry_sql))` — requires computing child_ancestry for every candidate row.

With parent_id (virtual or physical): `WHERE NOT EXISTS (SELECT 1 FROM table c WHERE c.parent_id = nodes.id)` — simple indexed lookup. This is a significant optimization opportunity, especially for ltree where `child_ancestry_sql` involves concatenation.

### Considered: virtual `path` column (ancestry + id)

A stored generated `path` column = `CONCAT(ancestry, id, '/')` would give `child_ancestry` for free as a column read. Every query that currently computes child_ancestry (descendants, children, leaves, subtree) could use the column directly. PG and SQLite support this (id available to generated columns at write time); MySQL does not (can't reference auto-increment).

Queries that would use `path` instead of computing `child_ancestry`:

- **children**: `WHERE ancestry = node.path` (currently `WHERE ancestry = CONCAT(ancestry, id, '/')`)
- **descendants**: `WHERE ancestry LIKE node.path || '%'` (currently `LIKE CONCAT(ancestry, id, '/') || '%'`)
- **leaves**: `NOT EXISTS (... WHERE ancestry = nodes.path)` (currently `ancestry = (child_ancestry_sql)`)
- **subtree**: same pattern, replaces CONCAT with column read

**Not pursued** — every simplification just removes a CONCAT, which is cheap SQL. The cost (double string storage, wider indexes, AR attribute overhead) far outweighs saving a concatenation. The parent_id approach for leaves (`WHERE parent_id = nodes.id`) goes the other direction — replacing a string match with an integer index lookup — which is a fundamentally better query, not just a simpler one.

### Version-over-version (v4.1 through master)

Query counts unchanged across all ancestry versions. IPS regressions traced to `delete_if(&:blank?)` in parse (v4.3, fixed #740) and `arrange_nodes` orphan_strategy branches (v5.0, fixed #741).

## ancestry vs closure_tree

830 nodes, three configurations:
- **ancestry** — mp3 format, scope-based (no AR associations)
- **ancestry+assoc** — mp3 with virtual parent_id, enabling `has_many :children` / `belongs_to :parent`
- **closure_tree** — hierarchy table with AR associations

Cold access: association caches reset between iterations.

### Caching behavior

| Operation               | ancestry              | ancestry+assoc          | closure_tree                        |
|-------------------------|-----------------------|-------------------------|-------------------------------------|
| ancestor_ids            | 3.1M i/s (parse)      | 3.1M i/s                | 1.2K i/s (queries hierarchy table)  |
| children (cached)       | n/a (scope, no cache) | 3.3M i/s (AR assoc)     | 3.3M i/s (AR assoc cache)           |
| descendants (cached)    | re-queries            | re-queries              | re-queries                          |

ancestry's `ancestor_ids` parses the ancestry string in Ruby (no DB query), so it's
fast enough that an ivar cache adds no practical value. An ivar cache was tested and
removed: real usage always involves DB calls (~100+ microseconds), dwarfing the
~0.16 microsecond cache benefit. The uncached path also got 2-11x faster in the same
cycle, further eliminating the case for caching.

closure_tree queries the hierarchy table for `ancestor_ids` every call. An ivar cache
there would be meaningful since each call costs ~1ms.

Descendants are not cached by either library — both return fresh relations on every call.

### Multi-node operations (preloading)

| Operation            | ancestry       | ancestry+assoc | closure_tree |
|----------------------|----------------|----------------|--------------|
| 4.preload(:children) | n/a (no assoc) | 2 queries      | 2 queries    |
| 4.descendants        | 5 queries      | 5 queries      | 2-4 queries  |

closure_tree's `self_and_descendants` association enables fewer queries when loading descendants for multiple nodes. However, `preload(:self_and_descendants)` currently errors with a SQL generation issue — an opportunity for closure_tree to fix and realize this advantage.

Both libraries support `preload(:children)` when associations are configured (ancestry with `parent: true`, closure_tree natively).

### Read operations (wide shape, IPS)

| Operation    | ancestry | ancestry+assoc | closure_tree |
|--------------|----------|----------------|--------------|
| root?        |     5.1M |           5.1M |         3.9M |
| ancestor_ids |     3.1M |           3.1M |         1.3K |
| parent       |    10.0K |          10.0K |         9.3K |
| children     |     9.2K |           8.8K |         6.4K |
| ancestors    |     8.8K |           9.0K |         1.3K |
| descendants  |     7.5K |           7.5K |         4.3K |
| roots        |     9.4K |           9.5K |         9.0K |
| leaf?        |    10.4K |          10.1K |         8.6K |
| arrange      |      277 |            278 |          185 |

Query counts are identical (1 each) for most operations. The IPS differences reflect query complexity (JOIN through hierarchy table vs LIKE/IN), not query count.

### Deep trees

On deep trees (50 levels), `ancestors` narrows significantly — ancestry's `WHERE id IN (25 ids)` gets heavier while closure_tree's hierarchy JOIN stays constant. `descendants` shows a similar pattern.

### At scale (7,800 nodes)

Running with `--scale 10` (~7,800 rows vs ~830) shifts several results. Ancestry still leads on most single-node reads, but the gap narrows and closure_tree pulls ahead on tree-wide operations like `arrange` and multi-node `descendants`.

#### Wide shape (scale 10 IPS)

| Operation     | ancestry | ancestry+assoc | closure_tree | Notes                            |
|---------------|----------|----------------|--------------|----------------------------------|
| ancestor_ids  |     3.1M |           3.0M |         5.2K | ancestry: string parse, no query |
| parent        |     9.8K |           9.5K |         9.2K |                                  |
| children      |     9.0K |           8.5K |         6.2K |                                  |
| ancestors     |     8.6K |           8.3K |         5.2K | changed (CT was 1.3K at s1)      |
| descendants   |     7.3K |           7.1K |         5.1K | changed (CT was 4.3K at s1)      |
| roots         |     6.5K |           6.4K |         6.6K | changed (ancestry led at s1)     |
| arrange       |     27.5 |           29.2 |         32.1 | changed (ancestry led at s1)     |
| 4.descendants |     1.1K |           1.4K |         1.4K |                                  |

#### Deep shape (scale 10 IPS)

| Operation     | ancestry | ancestry+assoc | closure_tree | Notes                          |
|---------------|----------|----------------|--------------|--------------------------------|
| children      |     8.1K |           7.2K |         5.2K |                                |
| ancestors     |     4.5K |           2.2K |         1.6K | all slower — deep IN/JOIN cost |
| descendants   |     1.9K |           1.8K |          397 |                                |
| arrange       |     28.2 |           28.0 |         32.9 | changed (ancestry led at s1)   |
| 4.descendants |      312 |            576 |          661 | changed (ancestry led at s1)   |

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
- **Eager loading** — closure_tree's `ancestors`/`descendants` are `has_many :through` — `preload` could work natively (once the SQL generation bug is fixed). ancestry's are scopes — `preload` doesn't apply (except `children` with `parent: true`). Unfortunatly has many through isn't the best for caching. This will require a rails patch.
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
