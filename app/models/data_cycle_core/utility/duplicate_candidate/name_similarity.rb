# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class NameSimilarity < Base
        PARAMETERS = ['name'].freeze

        class << self
          # Both the `%` operator and the reported score compare the current locale on both sides
          # (see Base.same_locale_scope), so a stored score is the similarity of two names that
          # exist in one and the same language. That language is the default locale, because
          # Feature::DuplicateCandidate.find_duplicates pins every recomputation to it: two contents
          # both named "Parkplatz Adolari" in German score 100, and an English reader is shown that
          # 100 beside "Parkplatz Adolari" and "parking space Adolari".
          #
          # @param content [DataCycleCore::Thing] content to find candidates for
          # @return [Array<Hash>, nil] candidate rows scored similarity * 100, nil when the content
          #   has no name in the current locale
          def duplicates(content:, **)
            return if content.name.blank?

            ActiveRecord::Base.transaction do
              ActiveRecord::Base.connection.exec_query('SET LOCAL pg_trgm.similarity_threshold = 0.8;')

              same_locale_scope(content)
                .where("(thing_translations.content ->> 'name') % ?", content.name)
                .pluck(:id, Arel.sql("similarity(thing_translations.content ->> 'name', #{ActiveRecord::Base.connection.quote(content.name)}) AS similarity"))
                .map { |t| { thing_duplicate_id: t[0], method: identifier, score: (t[1].to_f * 100).to_i } }
            end
          end
        end
      end
    end
  end
end
