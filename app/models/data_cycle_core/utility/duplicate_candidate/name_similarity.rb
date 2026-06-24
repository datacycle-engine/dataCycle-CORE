# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class NameSimilarity < Base
        PARAMETERS = ['name'].freeze

        class << self
          def duplicates(content:, **)
            return if content.name.blank?

            ActiveRecord::Base.transaction do
              ActiveRecord::Base.connection.exec_query('SET LOCAL pg_trgm.similarity_threshold = 0.8;')

              DataCycleCore::Thing
                .joins(:translations)
                .where(template_name: content.template_name)
                .where("(thing_translations.content ->> 'name') % ?", content.name)
                .where.not(id: content.id)
                .pluck(:id, Arel.sql("similarity(thing_translations.content ->> 'name', #{ActiveRecord::Base.connection.quote(content.name)}) AS similarity"))
                .map { |t| { thing_duplicate_id: t[0], method: identifier, score: (t[1].to_f * 100).to_i } }
            end
          end
        end
      end
    end
  end
end
