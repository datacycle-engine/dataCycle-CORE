# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class OnlyNameAndLocality < Base
        PARAMETERS = ['name', 'address'].freeze

        class << self
          # The address is stored untranslated in things.metadata, so only the name half of the rule
          # is locale bound (see Base.same_locale_scope).
          #
          # @param content [DataCycleCore::Thing] content to find candidates for
          # @return [Array<Hash>, nil] candidate rows scored 100, nil when the content has no name
          #   in the current locale or no address_locality
          def duplicates(content:, **)
            return if content.try(:name).blank? || content.try(:address)&.address_locality.blank?

            thing_ids = same_locale_scope(content)
              .where("thing_translations.content ->> 'name' = ?", content.name)
              .where("things.metadata -> 'address' ->> 'address_locality' = ?", content.address&.address_locality)
              .pluck(:id)

            candidate_rows(thing_ids, score: 100)
          end
        end
      end
    end
  end
end
