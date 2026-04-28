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

# Build table once with mp3-virt (has virtual parent_id column + indexes).
# Create 3 model classes on the same table with different has_ancestry options:
#   AncestryBase  — mp3, no associations (scope-based)
#   AncestryAssoc — mp3-virt, with has_many :children / belongs_to :parent
#   ClosureTreeNode — separate table, closure_tree gem
ancestry_table_model = TreeBench.build_config!("mp3-virt")

# Base ancestry model — same table, no associations
Object.send(:remove_const, :AncestryBase) if defined?(::AncestryBase)
ancestry_base = Class.new(ActiveRecord::Base) { self.table_name = "ancestry_nodes" }
Object.const_set(:AncestryBase, ancestry_base)
ancestry_base.has_ancestry(format: :materialized_path3, cache_depth: true)

# Assoc ancestry model — same table, with associations
ancestry_assoc = ancestry_table_model

puts "Building ancestry trees..."
scale = (ARGV.delete("--scale") ? ARGV.shift.to_i : 1)
target_dir = "results/#{scale}"
FileUtils.mkdir_p(target_dir)
ancestry_trees = TreeBench::TreeShapes.build_all(ancestry_assoc, scale: scale)
# Reload base model nodes to pick up the same data
ancestry_base_trees = {}
TreeBench::TreeShapes::SHAPES.each do |shape|
  at = ancestry_trees[shape]
  ancestry_base_trees[shape] = {
    root: ancestry_base.find(at[:root].id),
    mid:  ancestry_base.find(at[:mid].id),
    leaf: ancestry_base.find(at[:leaf].id),
    model: ancestry_base,
  }
end

puts "Building closure_tree trees..."
ct_trees = {}
TreeBench::TreeShapes::SHAPES.each do |shape|
  before = ClosureTreeNode.count
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  ct_trees[shape] = TreeBench::TreeShapes.build(shape, ClosureTreeNode, scale: scale)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  added = ClosureTreeNode.count - before
  puts "  #{shape}: #{added} records in #{'%.1f' % elapsed}s"
end

# Compare read operations
TreeBench::TreeShapes::SHAPES.each do |shape|
  ab = ancestry_base_trees[shape]  # ancestry without associations
  aa = ancestry_trees[shape]       # ancestry with associations
  ct = ct_trees[shape]

  # Base ancestry (scopes only)
  a_node = ab[:mid] ; a_leaf = ab[:leaf] ; a_klass = ab[:model]
  # Assoc ancestry (has_many :children, belongs_to :parent)
  v_node = aa[:mid] ; v_leaf = aa[:leaf] ; v_klass = aa[:model]
  # Closure tree
  c_node = ct[:mid] ; c_leaf = ct[:leaf] ; c_klass = ct[:model]

  # Grab 4 children of root for preload benchmarks — order by id for consistency
  a_depth1 = ab[:root].children.order(:id).limit(4).to_a
  v_depth1 = aa[:root].children.order(:id).limit(4).to_a
  c_depth1 = ct[:root].children.order(:id).limit(4).to_a

  Benchmark.items(metrics: metrics) do |x|
    x.compare_by :shape, :operation
    x.report_with row: :operation, column: :gem, grouping: [:shape], value: TreeBench::Suite::COMPACT_VALUE
    x.configure(force: true) if force
    x.metadata(db: TreeBench.db_name)

    # -- ancestry (mp3, scope-based — no has_many associations) --
    x.metadata(gem: "ancestry", shape: shape) do
      x.report(operation: "root?")               { a_node.root? }
      x.report(operation: "ancestor_ids")         { a_node.ancestor_ids }
      x.report(operation: "parent")               { a_node.parent }                    # scope: queries each call
      x.report(operation: "parent cached")        { a_node.parent }                    # scope: no cache, re-queries
      x.report(operation: "children")             { a_node.children.to_a }             # scope: fresh relation each call
      x.report(operation: "children cached")      { a_node.children.to_a }             # scope: no cache, re-queries
      x.report(operation: "ancestors")            { a_node.ancestors.to_a }
      x.report(operation: "ancestors cached")     { a_node.ancestors.to_a }            # scope: no cache, re-queries
      x.report(operation: "descendants")          { a_node.descendants.to_a }
      x.report(operation: "descendants cached")   { a_node.descendants.to_a }           # scope: no cache, re-queries
      x.report(operation: "roots")                { a_klass.roots.to_a }
      x.report(operation: "leaf?")                { a_leaf.leaf? }
      x.report(operation: "arrange")              { a_klass.arrange }
      # no has_many — each call is a separate scope query (N+1)
      x.report(operation: "4.each_parent") do
        a_klass.where(id: a_depth1.map(&:id)).each { |n| n.parent }
      end
      x.report(operation: "4.each_children") do
        a_klass.where(id: a_depth1.map(&:id)).each { |n| n.children.to_a }
      end
      x.report(operation: "4.descendants") do
        a_klass.where(id: a_depth1.map(&:id)).each { |n| n.descendants.to_a }
      end
    end

    # -- ancestry + associations (mp3-virt, virtual parent_id — has_many :children) --
    x.metadata(gem: "ancestry+assoc", shape: shape) do
      x.report(operation: "root?")               { v_node.root? }
      x.report(operation: "ancestor_ids")         { v_node.ancestor_ids }
      x.report(operation: "parent")               { v_node.association(:parent).reset; v_node.parent }  # cold: association reset
      x.report(operation: "parent cached")        { v_node.parent }                                      # warm: AR cache hit
      x.report(operation: "children")             { v_node.association(:children).reset; v_node.children.to_a }  # cold: association reset
      x.report(operation: "children cached")      { v_node.children.to_a }                                      # warm: AR cache hit
      x.report(operation: "ancestors")            { v_node.ancestors.to_a }                                      # scope: no cache
      x.report(operation: "ancestors cached")     { v_node.ancestors.to_a }                                      # scope: no cache, re-queries
      x.report(operation: "descendants")          { v_node.descendants.to_a }
      x.report(operation: "descendants cached")   { v_node.descendants.to_a }                                   # scope: no cache, re-queries
      x.report(operation: "roots")                { v_klass.roots.to_a }
      x.report(operation: "leaf?")                { v_leaf.leaf? }
      x.report(operation: "arrange")              { v_klass.arrange }
      x.report(operation: "4.each_parent") do
        v_klass.where(id: v_depth1.map(&:id)).each { |n| n.association(:parent).reset; n.parent }
      end
      x.report(operation: "4.includes(:parent)") do
        v_klass.where(id: v_depth1.map(&:id)).includes(:parent).each { |n| n.parent }
      end
      x.report(operation: "4.each_children") do
        v_klass.where(id: v_depth1.map(&:id)).each { |n| n.association(:children).reset; n.children.to_a }
      end
      x.report(operation: "4.preload(:children)") do
        v_klass.where(id: v_depth1.map(&:id)).preload(:children).each { |n| n.children.to_a }
      end
      x.report(operation: "4.descendants") do
        v_klass.where(id: v_depth1.map(&:id)).each { |n| n.descendants.to_a }
      end
    end

    # -- closure_tree --
    x.metadata(gem: "closure_tree", shape: shape) do
      x.report(operation: "root?")               { c_node.root? }
      x.report(operation: "ancestor_ids")         { c_node.association(:ancestor_hierarchies).reset; c_node.ancestor_ids }
      x.report(operation: "parent")               { c_node.association(:parent).reset; c_node.parent }  # cold: association reset
      x.report(operation: "parent cached")        { c_node.parent }                                      # warm: AR cache hit
      x.report(operation: "children")             { c_node.association(:children).reset; c_node.children.to_a }  # cold: association reset
      x.report(operation: "children cached")      { c_node.children.to_a }                                      # warm: AR cache hit
      x.report(operation: "ancestors")            { c_node.association(:self_and_ancestors).reset; c_node.ancestors.to_a }  # cold
      x.report(operation: "ancestors cached")     { c_node.ancestors.to_a }                                      # warm: has_many :through cache
      x.report(operation: "descendants")          { c_node.association(:self_and_descendants).reset; c_node.descendants.to_a }  # cold
      x.report(operation: "descendants cached")   { c_node.descendants.to_a }                                   # warm: has_many :through cache
      x.report(operation: "roots")                { c_klass.roots.to_a }
      x.report(operation: "leaf?")                { c_node.association(:children).reset; c_leaf.leaf? }
      x.report(operation: "arrange")              { c_klass.hash_tree }
      x.report(operation: "4.each_parent") do
        c_klass.where(id: c_depth1.map(&:id)).each { |n| n.association(:parent).reset; n.parent }
      end
      x.report(operation: "4.includes(:parent)") do
        c_klass.where(id: c_depth1.map(&:id)).includes(:parent).each { |n| n.parent }
      end
      x.report(operation: "4.each_children") do
        c_klass.where(id: c_depth1.map(&:id)).each { |n| n.association(:children).reset; n.children.to_a }
      end
      x.report(operation: "4.preload(:children)") do
        c_klass.where(id: c_depth1.map(&:id)).preload(:children).each { |n| n.children.to_a }
      end
      x.report(operation: "4.descendants") do
        c_depth1.each { |n| n.association(:self_and_descendants).reset; n.descendants.to_a }
      end
    end

    base = File.basename($PROGRAM_NAME, '.rb')
    x.save_file "#{target_dir}/#{base}.json"
    x.save_sql "#{target_dir}/#{base}.sql"
    x.report_output(ENV["OUTPUT"]) if ENV["OUTPUT"]
  end
end
