require_relative "../lib/tree_bench"

options = TreeBench::Suite.parse!
TreeBench.connect!

Benchmark.items(metrics: %w[queries rows ips]) do |x|
  TreeBench::Suite.setup(x, options, "write")
  meta = TreeBench::Suite.metadata(options)

  TreeBench::TreeShapes::SHAPES.each do |shape|
    model = TreeBench.build_config!(options[:config])
    t = TreeBench::TreeShapes.build(shape, model)

    x.metadata(**meta, shape: shape) do
      root = t[:root]
      node = t[:mid]
      leaf = t[:leaf]
      klass = t[:model]

      x.report(operation: "insert leaf") do
        ActiveRecord::Base.transaction do
          klass.create!(name: "bench_insert", parent: node)
          raise ActiveRecord::Rollback
        end
      end

      other_parent = klass.where.not(id: [node.id, root.id]).first

      x.report(operation: "move subtree") do
        ActiveRecord::Base.transaction do
          leaf.update!(parent: other_parent)
          raise ActiveRecord::Rollback
        end
      end

      x.report(operation: "destroy leaf") do
        ActiveRecord::Base.transaction do
          new_leaf = klass.create!(name: "to_destroy", parent: node)
          new_leaf.destroy
          raise ActiveRecord::Rollback
        end
      end

      x.report(operation: "parent=") do
        ActiveRecord::Base.transaction do
          leaf.update!(parent: other_parent)
          raise ActiveRecord::Rollback
        end
      end

      x.report(operation: "parent_id=") do
        ActiveRecord::Base.transaction do
          leaf.update!(parent_id: other_parent.id)
          raise ActiveRecord::Rollback
        end
      end
    end

    # Build tree from scratch — separate because it recreates tables
    x.metadata(**meta, shape: shape) do
      x.report(operation: "build tree") do
        TreeBench.build_config!(options[:config])
        TreeBench::TreeShapes.build(shape, model)
      end
    end
  end
end
