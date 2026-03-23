# ancestry vs closure_tree Performance Comparison

Benchmark: 830 nodes (3 shapes: wide/deep/mixed), PostgreSQL, Ruby 4.0.1, Rails 7.2.
Cold-access (association caches reset between iterations).

## Read Operations (wide shape, IPS — higher is better)

| Operation | ancestry | closure_tree | Notes |
|-----------|----------|--------------|-------|
| root? | 4,476,619 | 4,019,158 | Both pure Ruby. ancestry checks nil, CT checks `_ct_parent_id.nil?` |
| ancestor_ids | 3,234,780 | 1,496 | ancestry: pure Ruby string parse. CT: queries hierarchy table. Architectural difference — CT must hit DB |
| parent | 9,162 | 9,220 | Tie. Both 1 query |
| children | 9,979 | 6,393 | Both 1 query. CT's `has_many` adds association overhead on cold access, but caches on repeat |
| ancestors | 9,178 | 4,830 | Both 1 query. CT's JOIN through hierarchy table is heavier than ancestry's `WHERE id IN (...)` |
| descendants | 6,325 | 5,374 | Both 1 query. ancestry uses LIKE, CT uses JOIN. CT may win on very deep trees where LIKE degrades |
| roots | 10,684 | 8,866 | Both 1 query. Similar SQL, CT has more association setup overhead |
| leaf? | 10,592 | 8,619 | Both 1 query (children exists check) |
| arrange | 318 | 407 | CT wins. `hash_tree` uses ordered query via hierarchy table. ancestry loads all then sorts in Ruby |

## Query Counts

Identical for all operations (1 query each) except:
- `ancestor_ids`: ancestry 0 (pure Ruby), closure_tree 1 (hierarchy table)

## Where Each Gem Can Improve

### ancestry
- **Repeated children access**: Without `parent: true`, `children` is a scope (re-queries each call). With `parent: true`, it's a cached `has_many`. Consider making associations the default or easier to enable.
- **arrange performance**: Ruby-side sorting is slower than CT's DB-ordered approach. Could benefit from ordered query when depth cache is available.
- **ancestor_ids caching**: Pure Ruby parse is fast but runs on every call. Caching the parsed result could help methods that call it multiple times (path_ids, depth, root_id all re-parse).

### closure_tree
- **ancestor_ids**: Requires DB query for every call. Could cache the result on the Ruby object after first load.
- **Association overhead**: `has_many :through` setup for ancestors/descendants adds per-call cost even for single queries. Lighter scope-based approach for cold access could help.
- **Build tree cost**: 2x slower tree construction (0.5s vs 0.2s for 601 nodes) due to hierarchy table maintenance on every insert.

## Architectural Differences (not fixable by either side)

- **CT: ordered traversal** — hierarchy table stores generation order, enabling ordered depth-first walks without Ruby sorting. ancestry would need a position column.
- **CT: deep tree descendants** — JOIN on hierarchy table vs LIKE on string. At extreme depth, JOINs scale better than string matching.
- **ancestry: write efficiency** — single column UPDATE vs hierarchy table maintenance. ancestry's writes are structurally cheaper.
- **ancestry: storage** — O(n) single column vs O(n × depth) hierarchy table rows.

## Methodology

- `compare_bench.rb` in tree-bench repository
- Cold access: closure_tree associations reset before each iteration to measure first-access cost
- ancestry uses mp1 config (no cache columns, no associations) — the simplest configuration
- Same tree shapes built in both models via shared `TreeShapes` builder
