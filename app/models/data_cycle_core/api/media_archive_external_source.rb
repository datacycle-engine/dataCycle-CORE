# frozen_string_literal: true

module DataCycleCore
  module Api
    class MediaArchiveExternalSource < DataCycleCore::Api::ExternalSource
      def update(data)
        extend(DataCycleCore::Generic::MediaArchive::Import)
        load_transformations
        processed_items = []
        data.each do |key, object|
          template_name = get_object_template_name object
          processed_items << process_content(object, load_template(@target_type, template_name), key)
        end
        processed_items
      end

      def create(data)
        update(data)
      end

      def delete(data)
        content_id = data
          .map { |_, content| content['url'] }
          .map { |url| url.split('/').last }
          .uniq
          .first

        contents = @target_type.where(external_source_id: @external_source.id, external_key: content_id)

        original_id = data
          .map { |_, content| content['contentUrl'] }
          .map { |url| url.split('/')[-3] }
          .uniq
          .reject { |id| id == content_id }
          .first

        DataCycleCore::ContentContent.where(content_b_id: contents.map(&:id)).map(&:content_a).each do |linked_content|
          I18n.with_locale(linked_content.available_locales.first) do
            linked_content.set_data_hash(data_hash: linked_content.get_data_hash)
            linked_content.update(created_at: Time.zone.now)
          end
        end

        if original_id
          original = @target_type.find_by(external_source_id: @external_source.id, external_key: original_id)

          DataCycleCore::ContentContent.where(content_b_id: contents.map(&:id)).find_each do |content_relation|
            content_relation.update!(content_b_id: original.id)
          end
        end

        duplicated_content_relations = DataCycleCore::ContentContent
          .select(:content_a_id, :content_a_type, :relation_a,
                  :content_b_id, :content_b_type, :relation_b,
                  'MIN(created_at) AS "oldest_creation_date"')
          .group(:content_a_id, :content_a_type, :relation_a, :content_b_id, :content_b_type, :relation_b)
          .having('COUNT(*) > 1')

        duplicated_content_relations.each do |duplicated_relation|
          DataCycleCore::ContentContent.where(
            content_a_id: duplicated_relation.content_a_id,
            content_a_type: duplicated_relation.content_a_type,
            relation_a: duplicated_relation.relation_a,
            content_b_id: duplicated_relation.content_b_id,
            content_b_type: duplicated_relation.content_b_type,
            relation_b: duplicated_relation.relation_b
          ).where('created_at > ?', duplicated_relation.oldest_creation_date).destroy_all
        end

        contents.map(&:destroy!).first
      end
    end
  end
end
