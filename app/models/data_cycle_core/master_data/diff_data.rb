# frozen_string_literal: true

require 'hashdiff'

# rubocop:disable Rails/DeprecatedActiveModelErrorsMethods

module DataCycleCore
  module MasterData
    class DiffData
      attr_accessor :diff_hash, :errors

      def initialize
        @diff_hash = {}
        @errors = { error: [], info: [] }
      end

      def diff(a:, schema_a:, b:, schema_b: nil, partial_update: false)
        schema_b = schema_a if schema_b.blank?
        if schema_a.blank? || schema_a&.dig('name').blank? || schema_b&.dig('name').blank? || schema_a&.dig('name') != schema_b&.dig('name')
          errors[:error] << "The data compared are not of the same type. #{schema_a&.dig('name')} =/= #{schema_b&.dig('name')}"
          return self
        end
        schema_diff = ::Hashdiff.diff(schema_a, schema_b)
        if schema_diff.size.positive?
          errors[:error] << 'The schema differs between the two received content data. (try to update all schemas)'
          errors[:info] << ('difference in schema: ' + schema_diff.map { |item| item.join(' ') }.join(' | '))
          return self
        end
        diff_object = Differs::Object.new(a, b, schema_a&.dig('properties'), '', partial_update)
        @diff_hash = diff_object.diff_hash
        self
      end

      def diff?(a:, schema_a:, b:, schema_b: nil, partial_update: false)
        diff(a:, b:, schema_a:, schema_b:, partial_update:)
        !(diff_hash.blank? && errors[:error].blank?)
      end
    end
  end
end

# rubocop:enable Rails/DeprecatedActiveModelErrorsMethods
