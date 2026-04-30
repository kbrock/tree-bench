#!/usr/bin/env ruby
# frozen_string_literal: true

# gen_html.rb - Generate HTML tables and charts from existing benchmark JSON
#
# Usage:
#   bundle exec ruby gen_html.rb

require "bundler/setup"
require "benchmark/sweet"

target_dir = "results/1"

# --- Read bench configs: chart + HTML table ---

json = "#{target_dir}/read_bench_configs.json"
if File.exist?(json)
  # Chart
  Benchmark.items(metrics: %w[ips queries rows]) do |x|
    x.save_file json
    x.filter(config: %w[mp1 mp3 mp3-parent array ltree]) { |l| !l[:operation].start_with?("ancestor_ids") }
    x.compare_by :shape, :operation
    x.skip_unremarkable!
    x.report_with row: :operation, column: :config, grouping: [:shape, :metric], baseline: "mp3"
    x.format(:chart)
    x.report_output("#{target_dir}/read_bench_configs.html")
  end
  puts "Wrote #{target_dir}/read_bench_configs.html"

  # HTML table
  Benchmark.items(metrics: %w[ips queries rows]) do |x|
    x.save_file json
    x.compare_by :shape, :operation
    x.report_with row: :operation, column: :config, grouping: [:shape, :metric], baseline: "mp1"
    x.format(:html)
    x.report_output("#{target_dir}/read_bench_configs_table.html")
  end
  puts "Wrote #{target_dir}/read_bench_configs_table.html"
end

# --- Read bench versions: chart + HTML table ---

json = "#{target_dir}/read_bench_versions.json"
if File.exist?(json)
  version_filter = ->(l) { l[:version] != "phase7" }

  # Chart
  Benchmark.items(metrics: %w[ips queries rows]) do |x|
    x.save_file json
    x.filter(&version_filter)
    x.compare_by :config, :shape, :operation
    x.skip_unremarkable!
    x.report_with row: :operation, column: :version, grouping: [:shape, :metric], baseline: "v5.0.0"
    x.format(:chart)
    x.report_output("#{target_dir}/read_bench_versions.html")
  end
  puts "Wrote #{target_dir}/read_bench_versions.html"

  # HTML table
  Benchmark.items(metrics: %w[ips queries rows]) do |x|
    x.save_file json
    x.filter(&version_filter)
    x.compare_by :config, :shape, :operation
    x.report_with row: :operation, column: :version, grouping: [:shape, :metric], baseline: "v5.0.0"
    x.format(:html)
    x.report_output("#{target_dir}/read_bench_versions_table.html")
  end
  puts "Wrote #{target_dir}/read_bench_versions_table.html"
end

# --- Compare bench: HTML table ---

json = "#{target_dir}/compare_bench.json"
if File.exist?(json)
  Benchmark.items(metrics: %w[ips queries rows]) do |x|
    x.save_file json
    x.compare_by :shape, :operation
    x.report_with row: :operation, column: :config, grouping: [:shape, :metric], baseline: "mp3"
    x.format(:html)
    x.report_output("#{target_dir}/compare_bench.html")
  end
  puts "Wrote #{target_dir}/compare_bench.html"
end

# --- Write bench configs: HTML table ---

json = "#{target_dir}/write_bench_configs.json"
if File.exist?(json)
  Benchmark.items(metrics: %w[ips queries rows]) do |x|
    x.save_file json
    x.compare_by :shape, :operation
    x.report_with row: :operation, column: :config, grouping: [:shape, :metric], baseline: "mp1"
    x.format(:html)
    x.report_output("#{target_dir}/write_bench_configs.html")
  end
  puts "Wrote #{target_dir}/write_bench_configs.html"
end
