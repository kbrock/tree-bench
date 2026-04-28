require "active_record"
require "ancestry"
require "benchmark/sweet"
require "logger"
require "fileutils"
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
      ActiveRecord::Base.connection.execute("CREATE EXTENSION IF NOT EXISTS ltree")
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
        t.ancestry cache_depth: true
      end

      create_table :closure_tree_nodes, force: true do |t|
        t.string :name
        t.integer :parent_id
        t.integer :sort_order
        t.index :parent_id
      end

      create_table :closure_tree_node_hierarchies, id: false, force: true do |t|
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
    require_relative "ancestry_model"
    require_relative "closure_tree_model"
    create_tables!
  end

  def self.db_name
    case DB
    when "postgresql", "pg" then "pg"
    when "mysql2", "trilogy" then "mysql"
    else "sqlite"
    end
  end

  def self.ascii_collation
    case db_name
    when "pg" then "C"
    when "mysql" then "utf8mb4_bin"
    else nil
    end
  end

  # -- Config Registry --
  #
  # Each config is a single hash splatted into both t.ancestry and has_ancestry.
  # Both accept ancestry_format:, cache_depth:, parent:, root:.

  CONFIGS = {
    # Cross-format comparison (bare, no cached columns)
    "mp1"             => {},
    "mp2"             => { format: :materialized_path2 },
    "mp3"             => { format: :materialized_path3 },
    # Feature comparison (mp3 as primary format)
    "mp3-depth"       => { format: :materialized_path3, cache_depth: true },
    "mp3-parent"      => { format: :materialized_path3, cache_depth: true, parent: true },
    "mp3-virt"        => { format: :materialized_path3, cache_depth: :virtual, parent: :virtual },
    # PG-only formats
    "ltree"           => { format: :ltree, cache_depth: true },
    "ltree-virt"      => { format: :ltree, cache_depth: :virtual, parent: :virtual },
    "array"           => { format: :array, cache_depth: true },
  }.freeze

  def self.build_config!(config_name)
    opts = CONFIGS.fetch(config_name) { abort "Unknown config: #{config_name}. Use: #{CONFIGS.keys.join(', ')}" }

    ActiveRecord::Schema.define do
      create_table :ancestry_nodes, force: true do |t|
        t.string :name
        if t.respond_to?(:ancestry)
          t.ancestry **opts
        else
          # Fallback for ancestry versions without t.ancestry migration helper
          collation = TreeBench.ascii_collation
          col_opts = collation ? { collation: collation } : {}
          t.string :ancestry, **col_opts
          t.integer :ancestry_depth, default: 0 if opts[:cache_depth]
          t.index :ancestry
        end
      end
    end

    Object.send(:remove_const, :BenchNode) if defined?(::BenchNode)
    klass = Class.new(ActiveRecord::Base) { self.table_name = "ancestry_nodes" }
    Object.const_set(:BenchNode, klass)
    klass.has_ancestry(**opts)
    klass.reset_column_information
    klass
  end

  # -- Suite --

  module Suite
    def self.parse!
      options = { suite: "configs", config: "mp1", version: "current" }

      OptionParser.new do |opts|
        opts.banner = "Usage: ruby #{File.basename($PROGRAM_NAME)} [options]"
        opts.on("-c", "--config CONFIG", "Config: #{CONFIGS.keys.join(', ')}") { |v| options[:config] = v }
        opts.on("-v", "--version VERSION", "Version label") { |v| options[:suite] = "versions" ; options[:version] = v }
        opts.on("--all", "Run all configs") { options[:all] = true }
        opts.on("--force", "Re-run even if results exist") { options[:force] = true }
        opts.on("--metrics METRICS", "Metrics: queries,rows,ips (default: all)") { |v| options[:metrics] = v.split(",") }
        opts.on("--scale N", Integer, "Scale tree sizes by N (default: 1)") { |v| options[:scale] = v }
      end.parse!
      options
    end

    COMPACT_VALUE = -> (c, color: true) {
      num = c.central_tendency.round(1)
      whole, dec = num.to_s.split(".")
      formatted = whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      formatted = "#{formatted}.#{dec}" if dec
      val = "#{formatted} #{c.units}"
      color ? "\033[#{c.color}m#{val}\e[0m" : val
    }

    def self.configs(options)
      if options[:all]
        TreeBench::CONFIGS.select { |_, cfg| !cfg[:db] || cfg[:db] == TreeBench.db_name }.keys
      else
        [options[:config]]
      end
    end

    def self.setup(x, options)
      case options[:suite]
      when "configs"
        x.compare_by :shape, :operation
        x.report_with row: :operation, column: :config, grouping: -> c { "#{c[:shape]} #{c[:db]}" }, value: COMPACT_VALUE
      when "versions"
        x.compare_by :config, :shape, :operation
        x.report_with grouping: -> c { "#{c[:config]} #{c[:shape]} #{c[:db]}" }, row: :operation, column: :version, value: COMPACT_VALUE
      else
        abort "Unknown suite: #{options[:suite]}. Use: configs, versions"
      end

      x.configure(force: true) if options[:force]
      x.metadata(version: options[:version], db: TreeBench.db_name)
    end
  end

  # -- Tree Shapes --

  module TreeShapes
    SHAPES = %w[wide deep mixed].freeze
    NODE_POOL_SIZES = [2, 10, 50].freeze

    # Pick N nodes evenly spaced from a pool, returning { nodes_2: [...], nodes_10: [...], ... }.
    # Skips sizes where the pool is too small. Used for bulk *_of([records|ids]) benchmarks —
    # picks from different subtrees (caller seeds the pool with one node per parent) so the
    # bulk OR has actual work to do, instead of collapsing to one ancestry prefix.
    def self.pick_pools(pool)
      result = {}
      NODE_POOL_SIZES.each do |n|
        next if pool.size < n
        step = pool.size / n
        result[:"nodes_#{n}"] = (0...n).map { |i| pool[i * step] }
      end
      result
    end

    # Build all shapes into the same table. Returns { "wide" => {root:, mid:, leaf:, model:, nodes_N:}, ... }
    # All shapes coexist — gives ~814 rows at scale=1 for realistic index behavior.
    def self.build_all(model, scale: 1)
      trees = {}
      SHAPES.each do |shape|
        before = model.count
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        trees[shape] = send(:"build_#{shape}", model, scale: scale)
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        added = model.count - before
        puts "  #{shape}: #{added} records in #{'%.1f' % elapsed}s"
      end
      trees
    end

    def self.build(shape, model, scale: 1)
      send(:"build_#{shape}", model, scale: scale)
    end

    # 1 root, 100*scale children, 5 grandchildren each = 1+600*scale nodes
    def self.build_wide(model, scale: 1)
      root = model.create!(name: "root")
      mid = nil
      pool = []
      children_count = 100 * scale
      mid_idx = children_count / 2
      children_count.times do |i|
        child = model.create!(name: "child_#{i}", parent: root)
        mid = child if i == mid_idx
        pool << child # depth 1 — has grandchildren as descendants; different subtrees by definition
        5.times do |j|
          model.create!(name: "grandchild_#{i}_#{j}", parent: child)
        end
      end
      leaf = model.order(:id).last
      { root: root.reload, mid: mid.reload, leaf: leaf.reload, model: model }.merge(pick_pools(pool))
    end

    # 1 root, 50 levels deep, scale siblings at even levels = 50+25*scale nodes
    def self.build_deep(model, scale: 1)
      root = model.create!(name: "root")
      node = root
      mid = nil
      50.times do |i|
        child = model.create!(name: "deep_#{i}", parent: node)
        if i.even?
          scale.times do |s|
            model.create!(name: "deep_#{i}_sib#{s}", parent: node)
          end
        end
        mid = child if i == 25
        node = child
      end
      { root: root.reload, mid: mid.reload, leaf: node.reload, model: model }
    end

    # 3*scale roots, 5 children each, 3 grandchildren each, 2 great-grandchildren each = 51*scale nodes
    def self.build_mixed(model, scale: 1)
      roots = []
      mid = nil
      leaf = nil
      root_count = 3 * scale
      mid_root = root_count / 2
      root_count.times do |r|
        root = model.create!(name: "root_#{r}")
        roots << root
        5.times do |c|
          child = model.create!(name: "child_#{r}_#{c}", parent: root)
          mid = child if r == mid_root && c == 2
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
