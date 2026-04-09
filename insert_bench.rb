# insert_bench.rb — Measure INSERT cost with different cached columns
#
# Compares: base mp3, parent (virt/phys), depth (virt/phys)
# Prep: 10-node chain, insert at root vs deepest
#
# Usage: DB=pg ruby insert_bench.rb [--force] [--metrics queries,rows,ips]

require_relative "lib/tree_bench"

INSERT_CONFIGS = {
  "base"        => { format: :materialized_path3 },
  "parent-virt" => { format: :materialized_path3, parent: :virtual },
  "parent-phys" => { format: :materialized_path3, parent: true },
  "depth-virt"  => { format: :materialized_path3, cache_depth: :virtual },
  "depth-phys"  => { format: :materialized_path3, cache_depth: true },
}

CHAIN_DEPTH = 10
CHAIN_DATA = "c_" + "x" * 48  # 50 chars, chain setup
ROOT_DATA  = "r_" + "x" * 48  # 50 chars, insert at root
DEEP_DATA  = "d_" + "x" * 48  # 50 chars, insert at depth

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: DB=pg ruby #{File.basename($PROGRAM_NAME)} [options]"
  opts.on("--force", "Re-run even if results exist") { options[:force] = true }
  opts.on("--metrics METRICS", "Metrics: queries,rows,ips") { |v| options[:metrics] = v.split(",") }
end.parse!

target_dir = "results/1"
FileUtils.mkdir_p(target_dir)
TreeBench.connect!

INSERT_CONFIGS.each do |label, opts|
  puts "\n=== #{label} ==="

  # Fresh table for each config
  ActiveRecord::Schema.define do
    create_table :ancestry_nodes, force: true do |t|
      t.string :name
      t.ancestry **opts
    end
  end

  Object.send(:remove_const, :BenchNode) if defined?(::BenchNode)
  klass = Class.new(ActiveRecord::Base) { self.table_name = "ancestry_nodes" }
  Object.const_set(:BenchNode, klass)
  klass.has_ancestry(**opts)
  klass.reset_column_information

  # Build 10-node chain (depth 10)
  parent = nil
  CHAIN_DEPTH.times do |i|
    parent = klass.create!(name: CHAIN_DATA, parent: parent)
  end
  root = klass.roots.first
  deepest = parent

  puts "  chain: #{klass.count} nodes, root=#{root.id}, deepest=#{deepest.id}"

  Benchmark.items(metrics: options[:metrics] || %w[queries rows ips]) do |x|
    x.compare_by :operation
    x.report_with row: :operation, column: :config,
                  value: TreeBench::Suite::COMPACT_VALUE
    x.configure(force: true) if options[:force]

    x.metadata(config: label, db: TreeBench.db_name) do
      x.report(operation: "insert at root") do
        klass.create!(name: ROOT_DATA, parent: root)
      end

      x.report(operation: "insert at depth #{CHAIN_DEPTH}") do
        klass.create!(name: DEEP_DATA, parent: deepest)
      end
    end

    base = File.basename($PROGRAM_NAME, '.rb')
    x.save_file "#{target_dir}/#{base}_configs.json"
    x.save_sql "#{target_dir}/#{base}-#{label}-current.sql"
    x.report_output(ENV["OUTPUT"]) if ENV["OUTPUT"]
  end
end
