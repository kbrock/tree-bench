require "ancestry"

class AncestryNode < ActiveRecord::Base
  has_ancestry cache_depth: true
end
