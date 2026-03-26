require "json"
require "benchmark/sweet"

module TreeBench
  module MarkdownReport
    # Format a number with comma separators and optional decimal
    def self.format_number(num)
      whole, dec = num.round(1).to_s.split(".")
      formatted = whole.gsub(/(\d)(?=(\d{3})+(?!\d))/, '\\1,')
      dec && dec != "0" ? "#{formatted}.#{dec}" : formatted
    end

    def self.render(comparisons, title:, grouping: nil, row: :label, column: :metric, sort: false)
      lines = []
      lines << "# #{title}"
      lines << ""

      Benchmark::Sweet.table(comparisons, grouping: grouping, row: row, column: column, value: -> c { c }, sort: sort) do |header_value, table_rows|
        next if table_rows.empty?
        lines.concat(render_table(header_value, table_rows))
        lines << ""
      end

      lines.join("\n") << "\n"
    end

    def self.render_table(header_value, table_rows)
      lines = []
      lines << "### #{header_value}" if header_value
      lines << ""

      headers = table_rows.flat_map(&:keys).uniq

      # Build rows of formatted strings
      formatted_rows = table_rows.map do |row|
        headers.map do |key|
          val = row[key]
          if val.nil?
            ""
          elsif val.is_a?(Benchmark::Sweet::Comparison)
            render_cell(val)
          else
            val.to_s
          end
        end
      end

      # Column widths
      header_strs = headers.map(&:to_s)
      widths = header_strs.each_with_index.map do |h, i|
        values_max = formatted_rows.map { |r| r[i].length }.max || 0
        [h.length, values_max, 3].max
      end

      # Header
      lines << "| " + header_strs.each_with_index.map { |h, i| h.ljust(widths[i]) }.join(" | ") + " |"
      # Right-align data columns, left-align first (label) column
      lines << "| " + widths.each_with_index.map { |w, i| i == 0 ? "-" * w : "-" * (w - 1) + ":" }.join(" | ") + " |"

      # Data rows
      formatted_rows.each do |row|
        cells = row.each_with_index.map do |val, i|
          i == 0 ? val.ljust(widths[i]) : val.rjust(widths[i])
        end
        lines << "| " + cells.join(" | ") + " |"
      end

      lines
    end

    def self.render_cell(c)
      value = format_number(c.central_tendency)
      if c.best?
        "**#{value}**"
      else
        value
      end
    end
  end
end
