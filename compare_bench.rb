#!/usr/bin/env ruby
# frozen_string_literal: true

# Compare ancestry vs closure_tree on shared operations
# Run: DB=pg bundle exec ruby compare_bench.rb
# Separate from read_bench/write_bench to avoid polluting ancestry iteration.

require_relative "lib/tree_bench"

TreeBench.connect!
TreeBench.create_tables!
require_relative "lib/closure_tree_model"

metrics = %w[queries rows ips]

# Parse minimal options
force = ARGV.delete("--force")
if (idx = ARGV.index("--metrics"))
  ARGV.delete_at(idx)
  metrics = ARGV.delete_at(idx).split(",")
end

# Build ancestry model (plain mp1, no cache_depth)
ancestry_model = TreeBench.build_config!("mp1")

# Build identical trees in both models
puts "Building ancestry trees..."
ancestry_trees = TreeBench::TreeShapes.build_all(ancestry_model)

puts "Building closure_tree trees..."
ct_trees = {}
TreeBench::TreeShapes::SHAPES.each do |shape|
  before = ClosureTreeNode.count
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ct_trees[shape] = TreeBench::TreeShapes.build(shape, ClosureTreeNode)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  added = ClosureTreeNode.count - before
  puts "  #{shape}: #{added} records in #{'%.1f' % elapsed}s"
end

# Compare read operations
TreeBench::TreeShapes::SHAPES.each do |shape|
  at = ancestry_trees[shape]
  ct = ct_trees[shape]

  # Ancestry nodes
  a_node = at[:mid]
  a_root = at[:root]
  a_leaf = at[:leaf]
  a_klass = at[:model]

  # Closure tree nodes
  c_node = ct[:mid]
  c_root = ct[:root]
  c_leaf = ct[:leaf]
  c_klass = ct[:model]

  Benchmark.items(metrics: metrics) do |x|
    x.compare_by :shape, :operation
    x.report_with row: :operation, column: :gem, grouping: [:shape], value: TreeBench::Suite::COMPACT_VALUE
    x.configure(force: true) if force
    x.metadata(db: TreeBench.db_name)

    # NOTE: closure_tree children/ancestors/descendants are has_many associations
    # that cache after first load. ancestry (without parent: true) uses scopes
    # that return fresh relations each time. This is a real difference —
    # closure_tree wins on repeated access within a request.
    # We benchmark first-access (cold) by resetting associations each iteration.

    x.metadata(gem: "ancestry", shape: shape) do
      x.report(operation: "root?")          { a_node.root? }            # pure ruby
      x.report(operation: "ancestor_ids")   { a_node.ancestor_ids }     # pure ruby: parse string
      x.report(operation: "parent")         { a_node.parent }           # sql: find by id
      x.report(operation: "children")       { a_node.children.to_a }    # sql: scope (no cache)
      x.report(operation: "ancestors")      { a_node.ancestors.to_a }   # sql: WHERE id IN (...)
      x.report(operation: "descendants")    { a_node.descendants.to_a } # sql: WHERE ancestry LIKE
      x.report(operation: "roots")          { a_klass.roots.to_a }
      x.report(operation: "leaf?")          { a_leaf.leaf? }            # sql: children.exists?
      x.report(operation: "arrange")        { a_klass.arrange }         # 1 query + ruby sort
    end

    x.metadata(gem: "closure_tree", shape: shape) do
      x.report(operation: "root?")          { c_node.root? }                                                    # pure ruby: parent_id.nil?
      x.report(operation: "ancestor_ids")   { c_node.association(:ancestor_hierarchies).reset; c_node.ancestor_ids }  # sql: hierarchy table
      x.report(operation: "parent")         { c_node.association(:parent).reset; c_node.parent }                      # sql: find by parent_id
      x.report(operation: "children")       { c_node.association(:children).reset; c_node.children.to_a }             # sql: has_many (cached after this)
      x.report(operation: "ancestors")      { c_node.association(:self_and_ancestors).reset; c_node.ancestors.to_a }  # sql: JOIN hierarchy
      x.report(operation: "descendants")    { c_node.association(:self_and_descendants).reset; c_node.descendants.to_a } # sql: JOIN hierarchy
      x.report(operation: "roots")          { c_klass.roots.to_a }
      x.report(operation: "leaf?")          { c_node.association(:children).reset; c_leaf.leaf? }                      # sql: children.empty?
      x.report(operation: "arrange")        { c_klass.hash_tree }                                                     # 1 query + ruby sort
    end

    x.save_file $PROGRAM_NAME.sub(".rb", ".json")
  end
end
