require_relative "lib/tree_bench"

options = TreeBench::Suite.parse!
TreeBench.connect!

Benchmark.items(metrics: %w[queries rows ips]) do |x|
  TreeBench::Suite.setup(x, options)
  TreeBench::TreeShapes::SHAPES.each do |shape|
    model = TreeBench.build_config!(options[:config])
    t = TreeBench::TreeShapes.build(shape, model)

    x.metadata(shape: shape) do
      node = t[:mid]
      root = t[:root]
      leaf = t[:leaf]
      klass = t[:model]

      x.report(operation: "has_parent?")      { node.has_parent? }     # pure ruby: no parse
      # x.report(operation: "is_root?")       { root.is_root? }      # pure ruby: same as has_parent?
      x.report(operation: "ancestor_ids")     { node.ancestor_ids }   # pure ruby: parse
      # x.report(operation: "path_ids")       { node.path_ids }      # pure ruby: ancestor_ids + [id]
      # x.report(operation: "depth")          { leaf.depth }         # pure ruby: ancestor_ids.size (revisit with depth_cache)
      x.report(operation: "parent")           { node.parent }        # sql: single record by id
      x.report(operation: "children")         { node.children.to_a } # sql: WHERE ancestry = X
      # x.report(operation: "children.count") { node.children.count } # sql: same as children (revisit with counter_cache)
      # x.report(operation: "child_ids")      { node.child_ids }     # sql: same as children
      x.report(operation: "ancestors")        { node.ancestors.to_a } # sql: WHERE id IN (...)
      x.report(operation: "descendants")      { root.descendants.to_a } # sql: WHERE ancestry LIKE X
      # x.report(operation: "descendant_ids") { root.descendant_ids } # sql: same as descendants
      # x.report(operation: "subtree")        { root.subtree.to_a }  # sql: descendants + OR self
      # x.report(operation: "siblings")       { node.siblings.to_a } # sql: same as children (equality)
      # x.report(operation: "sibling_ids")    { node.sibling_ids }   # sql: same as children (equality)
      # x.report(operation: "root")           { leaf.root }          # sql: same as parent (revisit with root_id cache)
      x.report(operation: "roots")            { klass.roots.to_a }   # sql: WHERE ancestry IS NULL
      x.report(operation: "arrange")          { klass.arrange }      # full tree + ruby sorting
    end
  end
  x.save_file $PROGRAM_NAME.sub(".rb", "_#{options[:suite]}.json")
  x.save_sql $PROGRAM_NAME.sub(".rb", "-#{options[:version]}.sql")
end
