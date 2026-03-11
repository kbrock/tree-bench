require "active_record"
require "ancestry"
require "benchmark/sweet"
require "logger"
require "optparse"

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
    require_relative "tree_bench/ancestry_model"
    require_relative "tree_bench/closure_tree_model"
    create_tables!
  end

  def self.db_name
    case DB
    when "postgresql", "pg" then "pg"
    when "mysql2", "trilogy" then "mysql"
    else "sqlite"
    end
  end

  # -- Config Registry --

  CONFIGS = {
    "mp1" => {
      ancestry: { cache_depth: true },
      table: ->(t) {
        t.string :ancestry
        t.integer :ancestry_depth, default: 0
        t.index :ancestry
      },
    },
    "mp2" => {
      ancestry: { cache_depth: true, ancestry_format: :materialized_path2 },
      table: ->(t) {
        t.string :ancestry, null: false
        t.integer :ancestry_depth, default: 0
        t.index :ancestry
      },
    },
    "mp1-parent" => {
      ancestry: { cache_depth: true, parent: true },
      table: ->(t) {
        t.string :ancestry
        t.integer :ancestry_depth, default: 0
        t.integer :parent_id
        t.index :ancestry
      },
    },
    "mp2-parent" => {
      ancestry: { cache_depth: true, ancestry_format: :materialized_path2, parent: true },
      table: ->(t) {
        t.string :ancestry, null: false
        t.integer :ancestry_depth, default: 0
        t.integer :parent_id
        t.index :ancestry
      },
    },
    "mp1-parent-root" => {
      ancestry: { cache_depth: true, parent: true, root: true },
      table: ->(t) {
        t.string :ancestry
        t.integer :ancestry_depth, default: 0
        t.integer :parent_id
        t.integer :root_id
        t.index :ancestry
      },
    },
    "mp2-parent-root" => {
      ancestry: { cache_depth: true, ancestry_format: :materialized_path2, parent: true, root: true },
      table: ->(t) {
        t.string :ancestry, null: false
        t.integer :ancestry_depth, default: 0
        t.integer :parent_id
        t.integer :root_id
        t.index :ancestry
      },
    },
  }.freeze

  def self.build_config!(config_name)
    cfg = CONFIGS.fetch(config_name) { abort "Unknown config: #{config_name}. Use: #{CONFIGS.keys.join(', ')}" }

    ActiveRecord::Schema.define do
      create_table :ancestry_nodes, force: true do |t|
        t.string :name
        instance_exec(t, &cfg[:table])
      end
    end

    Object.send(:remove_const, :BenchNode) if defined?(::BenchNode)
    klass = Class.new(ActiveRecord::Base) { self.table_name = "ancestry_nodes" }
    Object.const_set(:BenchNode, klass)
    klass.has_ancestry(**cfg[:ancestry])
    klass.reset_column_information
    klass
  end

  # -- Suite --

  module Suite
    SUITES = {
      "configs" => {
        required: [:config],
        defaults: { tag: "current" },
        compare_by: [:config, :shape, :operation],
        report_with: { row: :operation, column: :config },
      },
      "versions" => {
        required: [:tag],
        defaults: { config: "mp1" },
        compare_by: [:version, :shape, :operation],
        report_with: { grouping: [:shape, :db], row: :operation, column: :version },
      },
    }.freeze

    def self.parse!
      options = {}

      OptionParser.new do |opts|
        opts.banner = "Usage: ruby bench/XXX_bench.rb -s SUITE [options]"
        opts.on("-s", "--suite SUITE", "Suite: #{SUITES.keys.join(', ')}") { |v| options[:suite] = v }
        opts.on("-c", "--config CONFIG", "Config: #{CONFIGS.keys.join(', ')}") { |v| options[:config] = v }
        opts.on("-t", "--tag TAG", "Version tag") { |v| options[:tag] = v }
        opts.on("--force", "Clear results file before running") { options[:force] = true }
      end.parse!

      options[:suite] || abort("--suite is required. Use: #{SUITES.keys.join(', ')}")
      options
    end

    def self.setup(x, options, bench_type)
      suite_name = options[:suite]
      suite = SUITES.fetch(suite_name) { abort "Unknown suite: #{suite_name}. Use: #{SUITES.keys.join(', ')}" }

      # Apply defaults, then validate required
      suite[:defaults]&.each { |k, v| options[k] ||= v }
      suite[:required].each do |key|
        options[key] || abort("--#{key} is required for '#{suite_name}' suite")
      end

      file = "results/#{suite_name}_#{bench_type}.json"
      File.delete(file) if options[:force] && File.exist?(file)

      x.save_file file
      x.compare_by(*suite[:compare_by])
      x.report_with(**suite[:report_with])
    end

    def self.metadata(options)
      { config: options[:config], version: options[:tag], db: TreeBench.db_name }
    end
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
