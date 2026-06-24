# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class OnlyNameAndLocality < Base
        PARAMETERS = ['name', 'address'].freeze

        class << self
          def duplicates(content:, **)
            return if content.try(:name).blank? || content.try(:address)&.address_locality.blank?

            DataCycleCore::Thing
              .joins(:translations)
              .where(template_name: content.template_name)
              .where("thing_translations.content ->> 'name' = ?", content.name)
              .where("things.metadata -> 'address' ->> 'address_locality' = ?", content.address&.address_locality)
              .where.not(id: content.id)
              .pluck(:id)
              .filter_map { |d| { thing_duplicate_id: d, method: identifier, score: 100 } }
          end
        end
      end
    end
  end
end
