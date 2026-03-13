require "closure_tree"

class ClosureTreeNode < ActiveRecord::Base
  has_closure_tree order: "sort_order"
end
