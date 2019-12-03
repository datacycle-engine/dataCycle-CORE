# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentHistoryLoader
      def get_data_hash(timestamp = nil)
        # return if !translated_locales.include?(I18n.locale) && changes.count.zero? # for new data-sets with pending data in it
        timestamp ||= history_valid.first + (history_valid.last - history_valid.first) / 2
        as_of(timestamp).try(:to_h, timestamp)
      end

      def diff(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        timestamp ||= history_valid.first + (history_valid.last - history_valid.first) / 2
        differ.diff(a: get_data_hash(timestamp), schema_a: schema, b: data, schema_b: template).diff_hash
      end

      def diff?(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        timestamp ||= history_valid.first + (history_valid.last - history_valid.first) / 2
        differ.diff?(a: get_data_hash(timestamp), schema_a: schema, b: data, schema_b: template)
      end

      def load_linked_objects(relation_name, same_language = false)
        properties = properties_for(relation_name)
        relation_a = relation_name
        relation_b = properties.dig('inverse_of')
        language_flag = same_language
        language_flag = properties_for(relation_name).dig('linked_language') == 'same' if properties.dig('linked_language').present?
        if properties.dig('link_direction') == 'inverse'
          result_object = DataCycleCore::Thing::History
          relation_name = :content_content_a_history
          content_id_sym = :content_b_history_id
          relation_a_name = relation_b
          relation_b_name = relation_a
          translation_table = :thing_history_translations
        else
          result_object = DataCycleCore::Thing
          relation_name = :content_content_b_history
          content_id_sym = :content_a_history_id
          relation_a_name = relation_a
          relation_b_name = relation_b
          translation_table = :thing_translations
        end
        relation_contents = result_object
          .joins(relation_name)
          .where({
            content_content_histories: {
              content_id_sym => id,
              relation_a: relation_a_name,
              relation_b: relation_b_name,
              content_b_history_type: result_object.to_s
            }
          })
        relation_contents = relation_contents.joins(:translations).where(translation_table => { locale: I18n.locale }) if language_flag
        relation_contents.order('content_content_histories.order_a ASC')
      end

      def load_embedded_objects(relation_name, same_language = true)
        language_flag = same_language
        language_flag = !properties_for(relation_name).dig('translated') if properties_for(relation_name).dig('translated').present?
        relation_contents = DataCycleCore::Thing::History
          .joins(:content_content_b_history)
          .where({
            content_content_histories: {
              content_a_history_id: id,
              relation_a: relation_name
            }
          })
        relation_contents = relation_contents.joins(:translations).where(thing_history_translations: { locale: I18n.locale }) if language_flag
        relation_contents.order('content_content_histories.order_a ASC')
      end

      def load_classifications(relation_name)
        DataCycleCore::Classification
          .joins(:classification_content_histories)
          .where(
            classification_content_histories: {
              content_data_history_id: id,
              relation: relation_name
            }
          )
      end

      def load_asset_relation(relation_name)
        DataCycleCore::Asset.joins(:asset_content)
          .find_by(asset_contents: { content_data_id: id, relation: relation_name })
      end

      def load_schedule(relation_name)
        DataCycleCore::Schedule::History.find_by(thing_history_id: id, relation: relation_name).order(created_at: :asc)
      end

      def as_of(timestamp)
        content_table_id = self.class.table_name.split('_')[0..-2].join('_').foreign_key
        history_table_translation = "#{self.class}::Translation".safe_constantize.arel_table

        return_data = self.class.joins(:translations)
          .where(content_table_id => send(content_table_id))
          .where(
            in_range(history_table_translation, timestamp)
          ).order(history_table_translation[:history_valid])
        return_data.last
      end
    end
  end
end
