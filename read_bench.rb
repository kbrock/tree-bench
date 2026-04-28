require_relative "lib/tree_bench"

options = TreeBench::Suite.parse!
target_dir = "results/#{options[:scale] || 1}"
FileUtils.mkdir_p(target_dir)
TreeBench.connect!

TreeBench::Suite.configs(options).each do |config|
  begin
    Benchmark.items(metrics: options[:metrics] || %w[queries rows ips]) do |x|
      TreeBench::Suite.setup(x, options)

      model = TreeBench.build_config!(config)
      trees = TreeBench::TreeShapes.build_all(model, scale: options[:scale] || 1)

      trees.each do |shape, t|
        x.metadata(config: config, shape: shape) do
          node = t[:mid]
          root = t[:root]
          leaf = t[:leaf]
          klass = t[:model]
          has_assoc = klass.reflect_on_association(:children)

          x.report(operation: "has_parent?")      { node.has_parent? }     # pure ruby: no parse
          # x.report(operation: "is_root?")       { root.is_root? }      # pure ruby: same as has_parent?
          x.report(operation: "ancestor_ids")        { node.ancestor_ids }
          # x.report(operation: "path_ids")       { node.path_ids }      # pure ruby: ancestor_ids + [id]
          # x.report(operation: "depth")          { leaf.depth }         # pure ruby: ancestor_ids.size (revisit with depth_cache)
          x.report(operation: "parent")           { node.parent }        # sql: single record by id
          if has_assoc # assoc: WHERE parent_id = X (reset to avoid cache hit)
            x.report(operation: "children") { node.association(:children).reset; node.children.to_a }
          else         # scope: WHERE ancestry = X
            x.report(operation: "children") { node.children.to_a }
          end
          # x.report(operation: "children.count") { node.children.count } # sql: same as children (revisit with counter_cache)
          # x.report(operation: "child_ids")      { node.child_ids }     # sql: same as children
          x.report(operation: "ancestors")        { node.ancestors.to_a } # sql: WHERE id IN (...)
          # All shapes coexist in one table (~814 rows), so node.descendants
          # returns a selective subset — not the whole table.
          x.report(operation: "descendants")      { node.descendants.to_a } # sql: WHERE ancestry LIKE X
          # x.report(operation: "descendant_ids") { node.descendant_ids } # sql: same as descendants
          # x.report(operation: "subtree")        { node.subtree.to_a }  # sql: descendants + OR self
          # x.report(operation: "siblings")       { node.siblings.to_a } # sql: same as children (equality)
          # x.report(operation: "sibling_ids")    { node.sibling_ids }   # sql: same as children (equality)
          # x.report(operation: "root")           { leaf.root }          # sql: same as parent (revisit with root_id cache)
          x.report(operation: "roots")            { klass.roots.to_a }   # sql: WHERE ancestry IS NULL
          if klass.respond_to?(:at_depth) && klass.column_names.include?("ancestry_depth")
            node_depth = node.depth
            x.report(operation: "at_depth(+1)")       { node.descendants.at_depth(node_depth + 1).to_a }
            x.report(operation: "to_depth(+2)")       { node.descendants.to_depth(node_depth + 2).to_a }
            x.report(operation: "at_depth(3)")        { klass.at_depth(3).to_a }
          end
          x.report(operation: "arrange")          { klass.arrange }      # full tree + ruby sorting
          x.report(operation: "arrange_subtree")  { node.subtree.arrange } # subtree arrange (not full table)

          # -- Association benchmarks (only with parent: true / :virtual) --
          # These show N+1 avoidance via includes. Comparing:
          #   loop approach (N+1 queries) vs includes (2 queries)
          if has_assoc
            depth1 = klass.where(ancestry_depth: 1)

            x.report(operation: "each.parent") do          # N+1: 1 query + N parent lookups
              depth1.each { |n| n.parent }
            end
            x.report(operation: "includes(:parent)") do    # 2 queries total
              depth1.includes(:parent).each { |n| n.parent }
            end

            x.report(operation: "each.children") do        # N+1: 1 query + N children lookups
              depth1.each { |n| n.children.to_a }
            end
            x.report(operation: "includes(:children)") do  # 2 queries total
              depth1.includes(:children).each { |n| n.children.to_a }
            end

            # Multi-node access: where(id: [...]).includes(:children)
            # Shows the association API advantage over children_of(single_node) loops
            multi_ids = [root.id, node.id]
            x.report(operation: "multi.includes(:children)") do
              klass.where(id: multi_ids).includes(:children).each { |n| n.children.to_a }
            end
          end
        end
      end

      base = File.basename($PROGRAM_NAME, '.rb')
      x.save_file "#{target_dir}/#{base}_#{options[:suite]}.json"
      x.save_sql "#{target_dir}/#{base}-#{config}-#{options[:version]}.sql"
      x.report_output(ENV["OUTPUT"]) if ENV["OUTPUT"]
    end
  rescue => e
    warn "SKIP #{config}: #{e.message}"
  end
end
