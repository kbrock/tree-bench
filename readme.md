# Tree Bench

[Results](http://thebrocks.net/tree-bench/results/) | [Source](https://github.com/kbrock/tree-bench)

## Goal

Measure the performance of Ruby tree/hierarchy gems. Find what's slow, prove what's fast, and give maintainers evidence for making changes.

Primarily benchmarks [`ancestry`](https://github.com/stefankroes/ancestry) with [`closure_tree`](https://github.com/ClosureTree/closure_tree) for cross-library comparison.

### What we tested

- Built a benchmark suite covering read operations, write operations, format comparisons, and version-over-version tracking.
- Tested `ancestry` configurations (`mp1`, `mp2`, `mp3`, `ltree`, `array`) with options like `cache_depth`, `parent`, and virtual columns.
- Compared against `closure_tree` to expose blind spots that only show up when you look at a different architecture.
- Trees are tested with `600`-`6,000` at `2`-`50` nodes deep.
- Note: most real-world hierarchies are broad and shallow
    - biological taxonomies go ~`9` levels deep
    - large org charts rarely exceed `12`.

### What we found

Both gems are Ruby libraries generating SQL. A technique one uses can often be adopted by the other. Comparing across gems is how you tell "this approach is fundamentally slower" from "this implementation has a fixable inefficiency."

- Comparing with `closure_tree` exposed that `ancestry` had a `387x` gap on `parent`.
- `closure_tree` does `arrange` better and pulls ahead at very large scales.
- `closure_tree` caches `parent_id` from the hierarchy. This can be done with `ancestry` as well.
- I had expected `closure_tree` to perform better with deep hierarchies, but the extra nodes slowed it down. 

Wrote up a more details description of our [findings.md](findings.md)

## Results

See the [results page](http://thebrocks.net/tree-bench/results/) for benchmarks, charts, and a glossary of configurations.

## TODO

- **Ordered descendants** -- where `closure_tree`'s hierarchy table ordering should shine
- **Write cost comparison** -- `ancestry` updates one column, `closure_tree` maintains a hierarchy table
- **Add more alternatives**
    - [`awesome_nested_set`](https://github.com/collectiveidea/awesome_nested_set) -- nested set pattern (`lft`/`rgt` columns)
    - [`acts_as_recursive_tree`](https://github.com/1and1/acts_as_recursive_tree) -- `parent_id` with `WITH RECURSIVE`
    - [`acts_as_sane_tree`](https://github.com/chrisroberts/acts_as_sane_tree) -- `parent_id` with `WITH RECURSIVE`

## Running

Requires local checkouts of [`ancestry`](https://github.com/stefankroes/ancestry) and [`benchmark-sweet`](https://github.com/kbrock/benchmark-sweet) as sibling directories.

```bash
bundle install

# compare ancestry configurations
DB=pg bundle exec ruby read_bench.rb --all
DB=pg bundle exec ruby write_bench.rb --all

# compare ancestry versions (requires ancestry git worktrees)
DB=pg bundle exec ruby read_bench.rb -v v5.0.0
DB=pg bundle exec ruby read_bench.rb -v master

# compare libraries
DB=pg bundle exec ruby compare_bench.rb

# generate HTML charts and tables
bundle exec ruby gen_html.rb
```
