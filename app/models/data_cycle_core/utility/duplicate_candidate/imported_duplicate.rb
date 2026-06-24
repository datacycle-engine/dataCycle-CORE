# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class ImportedDuplicate < Base
        PARAMETERS = ['external_key', 'external_source_id', 'external_system_syncs'].freeze

        class << self
          def duplicates(content:, **)
            return if content.external_source_id.blank? || content.external_key.blank?

            external_keys = [content.external_key] + content.external_system_syncs.where(external_system_id: content.external_source_id).pluck(:external_key)

            DataCycleCore::Thing
              .by_external_key(content.external_source_id, external_keys)
              .where.not(id: content.id)
              .pluck(:id)
              .map { |d| { thing_duplicate_id: d, method: identifier, score: 100 } }
          end
        end
      end
    end
  end
end
