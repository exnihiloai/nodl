module Nodl
  module Transformation
    Transformer = Struct.new(:handle, :path, :instructions, :templates, keyword_init: true)
  end
end
