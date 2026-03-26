#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate markdown reports from benchmark JSON files.
# Run: ruby markdown_report.rb
# Reads *.json in current directory, writes markdown to results/

require_relative "lib/markdown_report"

REPORTS = {
  "read_bench_configs.json" => {
    title: "Read Benchmarks — Config Comparison",
    compare_by: [:shape, :operation],
    grouping: -> c { "#{c[:shape]} (#{c[:metric]})" },
    row: :operation,
    column: :config,
  },
  "read_bench_versions.json" => {
    title: "Read Benchmarks — Version Comparison",
    compare_by: [:version, :shape, :operation],
    grouping: -> c { "#{c[:shape]} #{c[:db]} (#{c[:metric]})" },
    row: :operation,
    column: :version,
  },
  "write_bench_configs.json" => {
    title: "Write Benchmarks — Config Comparison",
    compare_by: [:shape, :operation],
    grouping: -> c { "#{c[:shape]} (#{c[:metric]})" },
    row: :operation,
    column: :config,
  },
  "write_bench_versions.json" => {
    title: "Write Benchmarks — Version Comparison",
    compare_by: [:version, :shape, :operation],
    grouping: -> c { "#{c[:shape]} #{c[:db]} (#{c[:metric]})" },
    row: :operation,
    column: :version,
  },
  "compare_bench.json" => {
    title: "ancestry vs closure_tree",
    compare_by: [:shape, :operation],
    grouping: -> c { "#{c[:shape]} (#{c[:metric]})" },
    row: :operation,
    column: :gem,
  },
}

Dir.mkdir("results") unless Dir.exist?("results")

REPORTS.each do |json_file, opts|
  next unless File.exist?(json_file)

  data = JSON.load(File.read(json_file))
  metrics = data.map { |e| e["metric"] }.uniq - %w[cached ignored]

  job = Benchmark::Sweet::Job.new(metrics: metrics)
  job.load_entries(json_file)

  compare_keys = opts[:compare_by]
  job.compare_by(*compare_keys)
  job.skip_unremarkable!

  comparisons = job.comparison_values

  if comparisons.empty?
    puts "#{json_file}: no data, skipping"
    next
  end

  md = TreeBench::MarkdownReport.render(
    comparisons,
    title: opts[:title],
    grouping: opts[:grouping],
    row: opts[:row],
    column: opts[:column],
  )

  out_file = "results/#{File.basename(json_file, '.json')}.md"
  File.write(out_file, md)
  puts "#{json_file} -> #{out_file}"
end
