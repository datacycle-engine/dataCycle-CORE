# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class OnlyTitle < Base
        PARAMETERS = ['name'].freeze

        class << self
          # Pairs contents of the same template carrying the identical name. It says nothing about
          # where a content is, so it scores 83 and stays below the threshold
          # `dc:duplicates:merge_duplicates[100,...]` merges at. That restraint is this module's
          # alone: NameSimilarity matches on the name and nothing else either, and scores
          # `similarity * 100`, so it reports an identical name at 100. A template running both
          # therefore offers such a pair twice, once held back and once not. What holds it back is
          # the merge naming a `duplicate_method` other than `name_similarity` - the shipped
          # schedule names `only_name_and_classification` - not naming one at all.
          #
          # @param content [DataCycleCore::Thing] content to find candidates for
          # @return [Array<Hash>, nil] candidate rows scored 83, nil when the content has no name
          #   in the current locale (see Base.same_locale_scope for why the locale is fixed)
          def duplicates(content:, **)
            return if content.name.blank?

            thing_ids = same_locale_scope(content)
              .where("thing_translations.content ->> 'name' = ?", content.name)
              .pluck(:id)

            candidate_rows(thing_ids, score: 83)
          end
        end
      end
    end
  end
end
