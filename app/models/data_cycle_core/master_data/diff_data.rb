# frozen_string_literal: true

require 'hashdiff'

module DataCycleCore
  module MasterData
    class DiffData
      attr_accessor :diff_hash

      def initialize
        @diff_hash = {}
      end

      def diff(a:, schema_a:, b:, schema_b: nil)
        schema_b = schema_a if schema_b.blank?
        if schema_a.blank? || schema_a&.dig('name').blank? || schema_b&.dig('name').blank? || schema_a&.dig('name') != schema_b&.dig('name')
          diff_hash[:error] << "The data compared are not of the same type. #{schema_a&.dig('name')} =/= #{schema_b&.dig('name')}"
          return diff_hash
        end
        schema_diff = HashDiff.diff(schema_a, schema_b)
        unless schema_diff.size.positive?
          diff_hash[:error] << 'The schema differs between the two received content data. (try to update all schemas)'
          return diff_hash[:info] << 'difference in schema: ' + schema_diff.map { |item| item.join(' ') }.join(' | ')
        end
        diff_object = Differ::Object.new(a, b, schema_a)
        diff_object.diff_hash
      end

      def diff?(a, b, schema)
        diff(a: a, b: b, schema_a: schema)
        diff_hash.empty?
      end
    end
  end
end
