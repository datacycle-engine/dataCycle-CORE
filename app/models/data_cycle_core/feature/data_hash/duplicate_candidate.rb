# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module DuplicateCandidate
        def create_duplicate_candidates
          duplicates = duplicate_method
          return if duplicates.blank?

          duplicates.each do |duplicate|
            thing_duplicates.create!(thing_duplicate_id: duplicate[:content]&.id, method: duplicate[:method], score: duplicate[:score]) unless duplicate_candidates.with_fp.any? { |c| c.duplicate_id == duplicate[:content]&.id }
          end
        end

        def merge_with_duplicate(duplicate)
          return if template_name != duplicate.template_name

          existing_query = content_content_b.map { |c| "(content_contents.content_a_id = '#{c.content_a_id}' AND content_contents.relation_a = '#{c.relation_a}')" }.join(' OR ')

          query1 = duplicate.content_content_b
          query1 = query1.where.not(existing_query) if existing_query.present?
          query1.update_all(content_b_id: id) # rubocop:disable Rails/SkipsModelValidations
          update_columns(external_key: external_key.presence || duplicate.external_key, external_source_id: external_source_id.presence || duplicate.external_source_id) #  rubocop:disable Rails/SkipsModelValidations

          existing_history_query = content_content_b_history.map { |c| "(content_content_histories.content_a_history_id = '#{c.content_a_history_id}' AND content_content_histories.relation_a = '#{c.relation_a}')" }.join(' OR ')

          query2 = duplicate.content_content_b_history
          query2 = query2.where.not(existing_history_query) if existing_history_query.present?
          query2.update_all(content_b_history_id: id) # rubocop:disable Rails/SkipsModelValidations

          duplicate.destroy_content
        end
      end
    end
  end
end
