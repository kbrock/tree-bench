require_relative "../lib/tree_bench"
require "benchmark/sweet"

TreeBench.setup!

gem_name = ENV.fetch("GEM", "ancestry")
model = gem_name == "closure_tree" ? ClosureTreeNode : AncestryNode
tag = ENV.fetch("TAG", "current")

Benchmark.items(metrics: %w[queries rows ips]) do |x|
  x.save_file "results/write_bench.json"
  x.compare_by :shape, :db, :operation
  x.report_with grouping: [:shape, :db], row: :operation, column: :version

  TreeBench::TreeShapes::SHAPES.each do |shape|
    TreeBench.create_tables!
    t = TreeBench::TreeShapes.build(shape, model)

    x.metadata gem: gem_name, db: TreeBench.db_name, shape: shape, version: tag do
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
    x.metadata gem: gem_name, db: TreeBench.db_name, shape: shape, version: tag do
      x.report(operation: "build tree") do
        TreeBench.create_tables!
        TreeBench::TreeShapes.build(shape, model)
      end
    end
  end
end
