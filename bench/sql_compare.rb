require_relative "../lib/tree_bench"

TreeBench.setup!

GEMS = {
  "ancestry"      => TreeBench::AncestryNode,
  "closure_tree"  => TreeBench::ClosureTreeNode,
}

def capture_sql(&block)
  queries = []
  callback = ->(_name, _start, _finish, _id, payload) {
    sql = payload[:sql]
    return unless sql
    return if payload[:name] == "SCHEMA"
    return if sql.match?(/^(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/)
    queries << sql
  }
  ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
  queries
end

puts "# SQL Comparison: ancestry vs closure_tree"
puts ""
puts "DB: #{TreeBench.db_name}"
puts ""
puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M')}"
puts ""

TreeBench::TreeShapes::SHAPES.each do |shape|
  puts "## Tree shape: #{shape}"
  puts ""

  GEMS.each do |gem_name, model|
    TreeBench.create_tables!
    t = TreeBench::TreeShapes.build(shape, model)
    root = t[:root]
    mid = t[:mid]
    leaf = t[:leaf]

    puts "### #{gem_name}"
    puts ""

    operations = {
      "parent"          => -> { mid.parent },
      "children"        => -> { mid.children.to_a },
      "children.count"  => -> { mid.children.count },
      "ancestors"       => -> { mid.ancestors.to_a },
      "descendants"     => -> { root.descendants.to_a },
      "siblings"        => -> { mid.siblings.to_a },
      "root"            => -> { leaf.root },
      "depth"           => -> { leaf.depth },
      "roots"           => -> { model.roots.to_a },
      "arrange"         => -> { gem_name == "ancestry" ? model.arrange : model.hash_tree },
      "insert leaf"     => -> { model.create!(name: "sql_test", parent: mid) },
    }

    operations.each do |op_name, op_block|
      queries = nil
      ActiveRecord::Base.transaction do
        queries = capture_sql(&op_block)
        raise ActiveRecord::Rollback
      end

      puts "#### #{op_name}"
      puts ""
      puts "```sql"
      queries.each { |q| puts q }
      puts "```"
      puts ""
    end
  end
end
