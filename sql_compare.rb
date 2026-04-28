require_relative "lib/tree_bench"

# Compare three SQL approaches for descendants_of(id):
#   1. LIKE literal     (FETCH mode — known-good, uses btree index)
#   2. LIKE ANY subquery (current subquery — breaks index)
#   3. JOIN approach     (arel_attribute pattern — proposed fix)

TreeBench.connect!
model = TreeBench.build_config!("mp3")
TreeBench::TreeShapes.build_all(model, scale: 1)

conn = ActiveRecord::Base.connection
node = model.where("ancestry IS NOT NULL").first
node_id = node.id
child_ancestry = node.child_ancestry  # e.g., "1/302/"

ids_10 = model.where("ancestry IS NOT NULL").limit(10).pluck(:id)

def run_explain(conn, label, sql)
  puts "\n--- #{label} ---"
  puts "  SQL: #{sql.gsub(/\s+/, ' ').strip}"
  result = conn.exec_query(sql)
  puts "  rows: #{result.rows.size}"
  plan = conn.exec_query("EXPLAIN ANALYZE #{sql}").rows.map(&:first).join("\n")
  puts "  PLAN:\n#{plan.gsub(/^/, '    ')}"
  puts
end

puts "=" * 70
puts "descendants_of(single id=#{node_id})"
puts "=" * 70

# 1. LIKE literal (what FETCH mode produces)
run_explain(conn, "LIKE literal",
  "SELECT * FROM ancestry_nodes WHERE ancestry LIKE '#{child_ancestry}%'")

# 2. LIKE ANY subquery (what SUBQUERY mode produces)
run_explain(conn, "LIKE ANY subquery",
  "SELECT * FROM ancestry_nodes WHERE ancestry LIKE ANY (
     SELECT CONCAT(ancestry, id, '/') || '%'
     FROM ancestry_nodes WHERE id = #{node_id}
   )")

# 3. JOIN approach (arel_attribute pattern)
run_explain(conn, "JOIN approach",
  "SELECT an.* FROM ancestry_nodes an
   JOIN ancestry_nodes src ON an.ancestry LIKE CONCAT(src.ancestry, src.id, '/%')
   WHERE src.id = #{node_id}")

puts "=" * 70
puts "descendants_of(10 ids: #{ids_10.join(',')})"
puts "=" * 70

# 1. OR'd LIKE literals (what FETCH mode produces for arrays)
likes = ids_10.map { |id| n = model.find(id); "ancestry LIKE '#{n.child_ancestry}%'" }.join(" OR ")
run_explain(conn, "OR'd LIKE literals",
  "SELECT * FROM ancestry_nodes WHERE #{likes}")

# 2. LIKE ANY subquery with multiple ids
run_explain(conn, "LIKE ANY subquery",
  "SELECT * FROM ancestry_nodes WHERE ancestry LIKE ANY (
     SELECT CONCAT(ancestry, id, '/') || '%'
     FROM ancestry_nodes WHERE id IN (#{ids_10.join(',')})
   )")

# 3. JOIN approach with multiple ids
run_explain(conn, "JOIN approach",
  "SELECT DISTINCT an.* FROM ancestry_nodes an
   JOIN ancestry_nodes src ON an.ancestry LIKE CONCAT(src.ancestry, src.id, '/%')
   WHERE src.id IN (#{ids_10.join(',')})")

puts "=" * 70
puts "children_of(single id=#{node_id}) — for comparison (equality, not LIKE)"
puts "=" * 70

run_explain(conn, "IN subquery (current)",
  "SELECT * FROM ancestry_nodes
   WHERE ancestry IN (SELECT CONCAT(ancestry, id, '/') FROM ancestry_nodes WHERE id = #{node_id})")

run_explain(conn, "JOIN approach",
  "SELECT an.* FROM ancestry_nodes an
   JOIN ancestry_nodes src ON an.ancestry = CONCAT(src.ancestry, src.id, '/')
   WHERE src.id = #{node_id}")
