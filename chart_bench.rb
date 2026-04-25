#!/usr/bin/env ruby
# frozen_string_literal: true

# chart_bench.rb - Render charts from existing benchmark results
#
# Loads read_bench_configs.json, renders grouped bar charts via Chart.js.
# One chart per shape+metric combination. No DB, no re-running benchmarks.
#
# Usage:
#   bundle exec ruby chart_bench.rb
#   bundle exec ruby chart_bench.rb --metrics ips

require "bundler/setup"
require "benchmark/sweet"

json_file = "results/1/read_bench_configs.json"
html_file = "results/1/read_bench_configs.html"

abort "No data: #{json_file}" unless File.exist?(json_file)

Benchmark.items(metrics: %w[ips queries rows]) do |x|
  x.save_file json_file

  x.compare_by :shape, :operation
  x.skip_unremarkable!

  # One chart per shape+metric (no metric collision).
  # X-axis: operations. Bars: configs side by side.
  x.report_with row:      :operation,
                column:   :config,
                grouping: [:shape, :metric],
                baseline: "mp3"

  x.format(:chart)
  x.report_output(html_file)
end

puts "Wrote #{html_file}"
