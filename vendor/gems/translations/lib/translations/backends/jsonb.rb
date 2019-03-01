# frozen_string_literal: true

require 'translations/backends/pg_hash'
require 'translations/arel/nodes/jsonb'
require 'translations/arel/nodes'

module Translations
  module Backends
    class Jsonb < PgHash
      def self.build_node(attr, locale)
        column_name = column_affix % attr
        Translations::Arel::Nodes::Jsonb.new(model_class.arel_table[column_name], build_quoted(locale))
      end
    end
  end
end
