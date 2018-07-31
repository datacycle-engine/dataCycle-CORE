# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Embedded < Linked
        private

        def parse_uuids(a)
          return if a.blank?
          data = a.is_a?(::String) ? [a] : a
          if a.is_a?(::Array)
            data = a.map { |item| item.is_a?(::Hash) ? item&.dig('id') : item }.compact || []
          end
          data = a&.ids if data.is_a?(ActiveRecord::Relation)
          raise ArgumentError, 'expected a uuid or list of uuids' unless data.is_a?(::Array)
          data
        end
      end
    end
  end
end
