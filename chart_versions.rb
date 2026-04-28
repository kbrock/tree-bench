#!/usr/bin/env ruby
# frozen_string_literal: true

# chart_versions.rb - "Getting faster over time" charts from version sweep data
#
# Loads read_bench_versions.json, renders grouped bar charts via Chart.js.
# One chart per shape+metric combination, baseline = master.
#
# Usage:
#   bundle exec ruby chart_versions.rb

require "bundler/setup"
require "benchmark/sweet"

json_file = "results/1/read_bench_versions.json"
html_file = "results/1/read_bench_versions.html"

abort "No data: #{json_file}" unless File.exist?(json_file)

Benchmark.items(metrics: %w[ips queries rows]) do |x|
  x.save_file json_file

  x.compare_by :config, :shape, :operation

  x.report_with row:      :operation,
                column:   :version,
                grouping: [:shape, :metric],
                baseline: "master"

  x.format(:chart)
  x.report_output(html_file)
end

puts "Wrote #{html_file}"
