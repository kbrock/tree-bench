require "active_record"
require "benchmark/sweet"
require "logger"

module TreeBench
  DB = ENV.fetch("DB", "sqlite")

  def self.connect!
    case DB
    when "postgresql", "pg"
      ActiveRecord::Base.establish_connection(
        adapter: "postgresql",
        database: "tree_bench",
        host: ENV.fetch("PGHOST", "localhost")
      )
    when "sqlite", "sqlite3"
      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: ":memory:"
      )
    when "mysql2"
      ActiveRecord::Base.establish_connection(
        adapter: "mysql2",
        database: "tree_bench",
        host: ENV.fetch("MYSQL_HOST", "localhost"),
        username: ENV.fetch("MYSQL_USER", "root"),
        password: ENV.fetch("MYSQL_PASSWORD", "")
      )
    when "trilogy"
      ActiveRecord::Base.establish_connection(
        adapter: "trilogy",
        database: "tree_bench",
        host: ENV.fetch("MYSQL_HOST", "localhost"),
        username: ENV.fetch("MYSQL_USER", "root"),
        password: ENV.fetch("MYSQL_PASSWORD", "")
      )
    else
      raise "Unknown DB=#{DB}. Use sqlite, postgresql, mysql2, or trilogy."
    end

    ActiveRecord::Base.logger = Logger.new(IO::NULL)
    ActiveRecord::Migration.verbose = false
  end

  def self.create_tables!
    ActiveRecord::Schema.define do
      create_table :ancestry_nodes, force: true do |t|
        t.string :name
        t.string :ancestry
        t.integer :ancestry_depth, default: 0
        t.index :ancestry
      end

      create_table :closure_tree_nodes, force: true do |t|
        t.string :name
        t.integer :parent_id
        t.integer :sort_order
        t.index :parent_id
      end

      create_table :closure_tree_node_hierarchies, force: true do |t|
        t.integer :ancestor_id, null: false
        t.integer :descendant_id, null: false
        t.integer :generations, null: false
        t.index [:ancestor_id, :descendant_id, :generations], unique: true, name: "ct_anc_desc_idx"
        t.index :descendant_id, name: "ct_desc_idx"
      end
    end
  end

  def self.setup!
    connect!
    create_tables!
  end

  def self.db_name
    case DB
    when "postgresql", "pg" then "pg"
    when "mysql2", "trilogy" then "mysql"
    else "sqlite"
    end
  end

  # -- Models --

  class AncestryNode < ActiveRecord::Base
    require "ancestry"
    has_ancestry cache_depth: true
  end

  class ClosureTreeNode < ActiveRecord::Base
    require "closure_tree"
    has_closure_tree order: "sort_order"
  end

  # -- Tree Shapes --

  module TreeShapes
    SHAPES = %w[wide deep mixed].freeze

    def self.build(shape, model)
      send(:"build_#{shape}", model)
    end

    # 1 root, 100 children, 5 grandchildren each = 601 nodes
    def self.build_wide(model)
      root = model.create!(name: "root")
      mid = nil
      100.times do |i|
        child = model.create!(name: "child_#{i}", parent: root)
        mid = child if i == 50
        5.times do |j|
          model.create!(name: "grandchild_#{i}_#{j}", parent: child)
        end
      end
      leaf = model.order(:id).last
      { root: root.reload, mid: mid.reload, leaf: leaf.reload, model: model }
    end

    # 1 root, 50 levels deep, 1-2 children per level ~75 nodes
    def self.build_deep(model)
      root = model.create!(name: "root")
      node = root
      mid = nil
      50.times do |i|
        child = model.create!(name: "deep_#{i}", parent: node)
        model.create!(name: "deep_#{i}_sib", parent: node) if i.even?
        mid = child if i == 25
        node = child
      end
      { root: root.reload, mid: mid.reload, leaf: node.reload, model: model }
    end

    # 3 roots, 5 children each, 3 grandchildren each, 2 great-grandchildren each = ~138 nodes
    def self.build_mixed(model)
      roots = []
      mid = nil
      leaf = nil
      3.times do |r|
        root = model.create!(name: "root_#{r}")
        roots << root
        5.times do |c|
          child = model.create!(name: "child_#{r}_#{c}", parent: root)
          mid = child if r == 1 && c == 2
          3.times do |g|
            grandchild = model.create!(name: "grandchild_#{r}_#{c}_#{g}", parent: child)
            2.times do |gg|
              leaf = model.create!(name: "great_#{r}_#{c}_#{g}_#{gg}", parent: grandchild)
            end
          end
        end
      end
      { root: roots.first.reload, mid: mid.reload, leaf: leaf.reload, model: model }
    end
  end
end

# Patch benchmark-sweet to handle AR 7.2+ transaction instrumentation events.
# QueryCounter subscribes to /active_record/ which now includes transaction
# events that lack :sql and :record_count keys.
module Benchmark::Sweet::Queries::QueryCounterTransactionPatch
  def callback(_name, _start, _finish, _id, payload)
    return if payload[:sql].nil? && payload[:record_count].nil?
    super
  end
end
Benchmark::Sweet::Queries::QueryCounter.prepend(Benchmark::Sweet::Queries::QueryCounterTransactionPatch)
