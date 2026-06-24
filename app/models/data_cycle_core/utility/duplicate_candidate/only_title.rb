# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class OnlyTitle < Base
        PARAMETERS = ['name'].freeze

        class << self
          def duplicates(content:, **)
            return if content.name.blank?

            DataCycleCore::Thing
              .joins(:translations)
              .where(template_name: content.template_name)
              .where("thing_translations.content ->> 'name' = ?", content.name)
              .where.not(id: content.id)
              .pluck(:id)
              .filter_map { |d| { thing_duplicate_id: d, method: identifier, score: 83 } }
          end
        end
      end
    end
  end
end
