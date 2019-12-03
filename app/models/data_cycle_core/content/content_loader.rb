# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentLoader
      def get_data_hash(timestamp = Time.zone.now)
        # return if changes.count.zero? # for new data-sets with pending data in it
        as_of(timestamp).try(:to_h, timestamp)
      end

      def diff(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        partial_update = template.present?
        if partial_update
          differ.diff(a: get_data_hash&.slice(*data.keys), schema_a: template, b: data, schema_b: template).diff_hash
        else
          differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template).diff_hash
        end
      end

      def diff?(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        partial_update = template.present?
        if partial_update
          differ.diff?(a: get_data_hash&.slice(*data.keys), schema_a: template, b: data, schema_b: template)
        else
          differ.diff?(a: get_data_hash, schema_a: schema, b: data, schema_b: template)
        end
      end

      def load_linked_objects(relation_name, same_language = false, languages = [I18n.locale])
        properties = properties_for(relation_name)
        relation_b = properties.dig('inverse_of')
        language_flag = same_language
        language_flag = properties.dig('linked_language') == 'same' if properties.dig('linked_language').present?
        load_relation(relation_name, relation_b, language_flag, languages, properties.dig('link_direction') == 'inverse')
      end

      def load_embedded_objects(relation_name, same_language = true, languages = [I18n.locale])
        language_flag = same_language
        language_flag = !properties_for(relation_name).dig('translated') if properties_for(relation_name).dig('translated').present?
        language_flag = false if same_language == false # overrules flag in template (needed for create_history and destroy)
        load_relation(relation_name, nil, language_flag, languages)
      end

      def load_relation(relation_a, relation_b, same_language, languages, inverse = false)
        if inverse
          relation_name = :content_a
          relation_a_name = relation_b
          relation_b_name = relation_a
        else
          relation_name = :content_b
          relation_a_name = relation_a
          relation_b_name = relation_b
        end

        relation_contents = send(relation_name).where(content_contents: {
          relation_a: relation_a_name,
          relation_b: relation_b_name
        })

        relation_contents = relation_contents.joins(:translations).where(thing_translations: { locale: languages }) if same_language
        relation_contents
      end

      def load_classifications(relation_name)
        DataCycleCore::Classification
          .joins(:classification_contents)
          .where(
            classification_contents: {
              content_data_id: id, relation: relation_name
            }
          )
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name(tree_label, alias_name)
      end

      def load_asset_relation(relation_name)
        DataCycleCore::Asset.joins(:asset_content)
          .find_by(asset_contents: { content_data_id: id, relation: relation_name })
      end

      def load_schedule(relation_name)
        DataCycleCore::Schedule.where(thing_id: id, relation: relation_name).order(created_at: :asc)
      end

      def as_of(timestamp)
        return self if updated_at.blank? || timestamp.blank? || timestamp >= updated_at

        history_table = DataCycleCore::Thing::History.arel_table
        history_table_translation = DataCycleCore::Thing::History::Translation.arel_table

        return_data = histories.joins(
          history_table
            .join(history_table_translation)
            .on(history_table[:id].eq(history_table_translation[:thing_history_id]))
            .join_sources
        ).where(
          in_range(history_table_translation, timestamp)
        ).order(history_table_translation[:history_valid])
        return_data.last
      end
    end
  end
end
