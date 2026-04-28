require_relative "lib/tree_bench"

# Minimal SQL + EXPLAIN diagnostic for the *_of regression investigation.
# Compares subquery path (default) vs fetch path (ANCESTRY_FETCH=true).
#
# Usage:
#   DB=pg ruby explain_bench.rb                    # subquery mode (default)
#   ANCESTRY_FETCH=true DB=pg ruby explain_bench.rb  # fetch mode (to_node)
#
# Or both in sequence:
#   DB=pg ruby explain_bench.rb && ANCESTRY_FETCH=true DB=pg ruby explain_bench.rb

TreeBench.connect!
model = TreeBench.build_config!("mp3")
trees = TreeBench::TreeShapes.build_all(model, scale: 1)

t = trees["wide"]
node = t[:mid]
node_id = node.id
klass = t[:model]
nodes_10 = t[:nodes_10] || []
ids_10 = nodes_10.map(&:id)
scope_10 = klass.where(id: ids_10)

conn = ActiveRecord::Base.connection
mode = ENV["ANCESTRY_FETCH"].to_s == "true" ? "FETCH (to_node)" : "SUBQUERY (default)"
puts "=" * 70
puts "Mode: #{mode}"
puts "=" * 70

def explain_op(conn, label)
  puts "\n--- #{label} ---"

  # Get the relation (no .to_a yet)
  relation = yield

  # Capture queries during .to_a
  queries = []
  cb = ->(*, payload) { queries << payload[:sql] unless payload[:sql].start_with?("EXPLAIN") }
  ActiveSupport::Notifications.subscribe("sql.active_record", &cb)
  result = relation.to_a
  ActiveSupport::Notifications.unsubscribe(cb)

  puts "  queries: #{queries.size}"
  puts "  rows:    #{result.size}"
  queries.each_with_index do |sql, i|
    puts "  SQL[#{i}]: #{sql}"
  end

  # EXPLAIN via raw SQL on captured query (handles bind params by substitution)
  if queries.any?
    last_sql = queries.last.gsub(/\$\d+/) { |m| "'?'" }
    begin
      plan = conn.exec_query("EXPLAIN ANALYZE #{last_sql}").rows.map(&:first).join("\n")
      puts "  EXPLAIN:\n#{plan.gsub(/^/, '    ')}"
    rescue => e
      puts "  EXPLAIN failed: #{e.message.lines.first.strip}"
    end
  end
  puts
rescue => e
  puts "  ERROR: #{e.message.lines.first.strip}"
  puts
end

# The regressed operations
# Return relations (no .to_a) so explain_op can call .explain
explain_op(conn, "leaves_of(rec)")          { klass.leaves_of(node) }
explain_op(conn, "leaves_of(id)")           { klass.leaves_of(node_id) }
explain_op(conn, "leaves_of([rec×10])")     { klass.leaves_of(nodes_10) }
explain_op(conn, "leaves_of([id×10])")      { klass.leaves_of(ids_10) }
explain_op(conn, "descendants_of(id)")      { klass.descendants_of(node_id) }
explain_op(conn, "descendants_of([id×10])") { klass.descendants_of(ids_10) }
explain_op(conn, "indirects_of(id)")        { klass.indirects_of(node_id) }
explain_op(conn, "children_of(id)")         { klass.children_of(node_id) }
explain_op(conn, "children_of(scope)")      { klass.children_of(scope_10) }
explain_op(conn, "siblings_of(id)")         { klass.siblings_of(node_id) }
