# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module DuplicateCandidate
        include Comparable

        def duplicate_candidates_allowed?
          DataCycleCore::Feature::DuplicateCandidate.allowed?(self)
        end

        def find_duplicates
          DataCycleCore::Feature::DuplicateCandidate.find_duplicates(self)
        end

        # The duplicate candidates of this content, prepared for the APIv4 duplicates endpoint. A pair
        # can have one candidate row per detection method (unique index on thing_ids + method), so the
        # rows of a pair are collapsed into a single entry carrying the highest score and every method
        # - the way the backend presents them, too (DuplicateCandidateHelper#duplicate_score_tag).
        #
        # The locale is resolved per duplicate rather than taken from the ambient one, so a title does
        # not come back empty for a duplicate that has no translation in the requested language.
        # @param false_positive [Boolean] return the dismissed pairs instead of the active ones
        # @param languages [Array<String>, nil] requested languages, best match per duplicate wins
        # @param limit [Integer, nil] number of pairs to return, paged in the database
        # @param offset [Integer, nil] number of pairs to skip, only applied together with +limit+
        # @param visible_scope [ActiveRecord::Relation, nil] things the caller may see
        # @return [Array<Hash>] one entry per duplicate content, highest score first
        def duplicate_candidates_for_api(false_positive: false, languages: nil, limit: nil, offset: nil, visible_scope: nil)
          candidates = duplicate_candidates_for_api_scope(false_positive:, visible_scope:)
          candidates = candidates.where(duplicate_id: paged_duplicate_ids(candidates, limit:, offset:)) if limit.present?

          candidates.includes(duplicate: :translations).group_by(&:duplicate_id).filter_map { |_id, rows|
            duplicate = rows.first.duplicate
            next if duplicate.nil?

            I18n.with_locale(duplicate.first_available_locale(languages) || I18n.locale) do
              {
                '@id' => duplicate.id,
                '@type' => duplicate.api_type,
                'name' => duplicate.title,
                'dct:modified' => duplicate.updated_at,
                'dc:score' => rows.filter_map { |r| r.score&.to_f }.max,
                'dc:duplicateMethod' => rows.filter_map(&:duplicate_method).uniq.sort,
                'dc:falsePositive' => rows.any?(&:false_positive)
              }
            end
          }.sort_by { |entry| [-entry['dc:score'].to_f, entry['@id']] }
        end

        # Number of duplicates (not candidate rows) the API would list, for the +meta+ section.
        # @param false_positive [Boolean] count the dismissed pairs instead of the active ones
        # @param visible_scope [ActiveRecord::Relation, nil] things the caller may see
        # @return [Integer]
        def duplicate_candidates_count_for_api(false_positive: false, visible_scope: nil)
          duplicate_candidates_for_api_scope(false_positive:, visible_scope:).reorder(nil).distinct.count(:duplicate_id)
        end

        # +visible_scope+ restricts the candidates to the duplicates the caller may see, as a subquery
        # rather than a list of ids: the scope of an API token can cover a large part of the data.
        # Ordering and select values of the incoming relation are dropped, so it stays usable as one -
        # a scope filter may bring its own (e.g. the rank of a fulltext parameter).
        # @param false_positive [Boolean] the dismissed pairs instead of the active ones
        # @param visible_scope [ActiveRecord::Relation, nil] things the caller may see
        # @return [ActiveRecord::Relation]
        def duplicate_candidates_for_api_scope(false_positive: false, visible_scope: nil)
          candidates = false_positive ? duplicate_candidates.with_fp : duplicate_candidates

          return candidates if visible_scope.nil?

          candidates.where(duplicate_id: visible_scope.except(:order, :select).select(:id))
        end

        # The duplicate_ids of one page, ordered the way the rendered entries are: highest score
        # first, the id as tiebreaker so paging over equal scores neither drops nor repeats a pair.
        # Grouping in the database keeps a content with many candidates from loading all of them.
        # @return [Array<String>]
        def paged_duplicate_ids(candidates, limit:, offset: nil)
          candidates
            .reorder(nil)
            .group(:duplicate_id)
            .order(Arel.sql('COALESCE(MAX(duplicate_candidates.score), 0) DESC, duplicate_candidates.duplicate_id ASC'))
            .limit(limit)
            .offset(offset)
            .pluck(:duplicate_id)
        end

        def <=>(other)
          # nativ > imported
          return 1 if external_source_id.blank? && other.external_source_id.present?
          return -1 if other.external_source_id.blank? && external_source_id.present?

          # assets are sorted by size
          if try(:width) && try(:height) && other.try(:width) && other.try(:height)
            return 1 if width * height > other.width * other.height
            return -1 if other.width * other.height > width * height
          end

          # more connections are better
          return 1 if linked_contents.size > other.linked_contents.size
          return -1 if linked_contents.size < other.linked_contents.size

          0 # equivalent
        end

        def original
          return @original if defined? @original

          @original = original_id.present? ? DataCycleCore::Thing.find_by(id: original_id) : nil
        end
      end
    end
  end
end
