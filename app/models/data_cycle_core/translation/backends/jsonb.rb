# frozen_string_literal: true

module DataCycleCore
  module Translation
    module Backends
      class Jsonb < PgHash
        def self.build_node(attr, locale)
          column_name = column_affix % attr
          Arel::Nodes::Jsonb.new(model_class.arel_table[column_name], build_quoted(locale))
        end
      end
    end
  end
end
