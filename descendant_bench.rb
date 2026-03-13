require_relative "lib/tree_bench"

options = TreeBench::Suite.parse!
TreeBench.connect!

Benchmark.items(metrics: %w[queries rows ips]) do |x|
  TreeBench::Suite.setup(x, options)
  model = TreeBench.build_config!(options[:config])
  t = TreeBench::TreeShapes.build("wide", model)

  x.metadata(shape: "wide") do
    root = t[:root]
    mid = t[:mid]
    klass = t[:model]

    x.report(operation: "descendants")    { root.descendants.to_a }
    x.report(operation: "descendant_ids") { root.descendant_ids }
    x.report(operation: "subtree")        { root.subtree.to_a }
    x.report(operation: "children")       { mid.children.to_a }
    x.report(operation: "roots")          { klass.roots.to_a }
  end

  x.save_file $PROGRAM_NAME.sub(".rb", "_#{options[:suite]}.json")
  x.save_sql $PROGRAM_NAME.sub(".rb", "-#{options[:version]}.sql")
end
