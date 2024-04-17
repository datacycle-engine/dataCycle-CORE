# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentHistoryLoader
      def get_data_hash # rubocop:disable Naming/AccessorMethodName
        try(:to_h)
      end

      def diff(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template).diff_hash
      end

      def diff?(data, template = nil)
        differ = DataCycleCore::MasterData::DiffData.new
        differ.diff?(a: get_data_hash, schema_a: schema, b: data, schema_b: template)
      end

      def load_linked_objects(relation_name, _filter = nil, same_language = false, _languages = ['de'], _overlay_flag = false)
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
          order_tiebreak = :content_a_history_id
        else
          result_object = DataCycleCore::Thing
          relation_name = :content_content_b_history
          content_id_sym = :content_a_history_id
          relation_a_name = relation_a
          relation_b_name = relation_b
          translation_table = :thing_translations
          order_tiebreak = :content_b_history_id
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
        relation_contents.order(order_a: :asc, order_tiebreak => :asc)
      end

      def load_embedded_objects(relation_name, _filter = nil, same_language = true, _languages = ['de'], _overlay_flag = false)
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
        relation_contents.order('content_content_histories.order_a ASC, content_content_histories.content_b_history_id ASC')
      end

      def load_classifications(relation_name, _overlay_flag)
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
          .where(asset_contents: { content_data_id: id, relation: relation_name })
      end

      def load_schedule(relation_name, _overlay_flag = false)
        DataCycleCore::Schedule::History.where(thing_history_id: id, relation: relation_name).order(created_at: :asc)
      end

      # timeseries don't have a history, load timeseries from related thing
      def load_timeseries(relation_name, _from = nil, _to = nil, _group_by = nil)
        DataCycleCore::Timeseries.where(thing_id: thing.id, property: relation_name).order(timestamp: :asc)
      end

      def load_collections(property_name)
        DataCycleCore::Collection.joins(:content_collection_link_histories).where(content_collection_link_histories: { thing_history_id: id, relation: property_name }).order(order_a: :asc)
      end

      def as_of(_timestamp)
        raise 'as_of in history is no longer possible (app/models/data_cycle_core/content/content_history_loader.rb)'
      end
    end
  end
end
