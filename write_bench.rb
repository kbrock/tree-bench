require_relative "lib/tree_bench"

options = TreeBench::Suite.parse!
TreeBench.connect!

TreeBench::Suite.configs(options).each do |config|
  begin
  # Build each shape — measured for queries/rows only (one-shot, not IPS).
  # No truncate between shapes, so they accumulate into one big table (~814 rows).
  model = TreeBench.build_config!(config)
  trees = {}

  Benchmark.items(metrics: %w[queries rows]) do |x|
    TreeBench::Suite.setup(x, options)

    TreeBench::TreeShapes::SHAPES.each do |shape|
      x.metadata(config: config, shape: shape) do
        x.report(operation: "build tree") do
          trees[shape] = TreeBench::TreeShapes.build(shape, model)
        end
      end
    end

    x.save_file $PROGRAM_NAME.sub(".rb", "_#{options[:suite]}.json")
    x.save_sql $PROGRAM_NAME.sub(".rb", "-#{config}-#{options[:version]}.sql")
  end

  # CRUD operations — all shapes already coexist in the table from above.
  Benchmark.items(metrics: options[:metrics] || %w[queries rows ips]) do |x|
    TreeBench::Suite.setup(x, options)

    trees.each do |shape, t|
      x.metadata(config: config, shape: shape) do
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
    end

    x.save_file $PROGRAM_NAME.sub(".rb", "_#{options[:suite]}.json")
    x.save_sql $PROGRAM_NAME.sub(".rb", "-#{config}-#{options[:version]}.sql")
  end

  rescue => e
    warn "SKIP #{config}: #{e.message}"
  end
end
