# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentLoader
      def get_data_hash # rubocop:disable Naming/AccessorMethodName
        try(:to_h)
      end

      def get_data_hash_partial(keys)
        try(:to_h_partial, keys)
      end

      def diff(data, template = nil, partial_update = false)
        diff_obj(data, template, partial_update).diff_hash
      end

      def diff_obj(data, template = nil, partial_update = false)
        differ = DataCycleCore::MasterData::DiffData.new
        if template.present?
          differ.diff(a: get_data_hash_partial(data.keys), schema_a: template, b: data, schema_b: template, partial_update:)
        else
          differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template, partial_update:)
        end
      end

      def diff?(data, template = nil, partial_update = false)
        differ = DataCycleCore::MasterData::DiffData.new
        if template.present?
          differ.diff?(a: get_data_hash_partial(data.keys), schema_a: template, b: data, schema_b: template, partial_update:)
        else
          differ.diff?(a: get_data_hash, schema_a: schema, b: data, schema_b: template, partial_update:)
        end
      end

      def load_linked_objects(relation_name, filter = nil, same_language = false, languages = [I18n.locale], overlay_flag = false)
        properties = properties_for(relation_name, overlay_flag)
        return [] if properties.nil?
        relation_b = properties.dig('inverse_of')
        language_flag = same_language
        language_flag = properties.dig('linked_language') == 'same' if properties.dig('linked_language').present?
        load_relation(relation_name, relation_b, language_flag, languages, filter, properties.dig('link_direction') == 'inverse', overlay_flag)
      end

      def load_embedded_objects(relation_name, filter = nil, same_language = true, languages = [I18n.locale], overlay_flag = false)
        return [] if properties_for(relation_name, overlay_flag).nil?

        load_relation(relation_name, nil, same_language, languages, filter, false, overlay_flag)
      end

      def load_relation(relation_a, relation_b, same_language, languages, filter = nil, inverse = false, _overlay_flag = false)
        if inverse
          relation_name = :content_a
          relation_a_name = relation_b
          relation_b_name = relation_a
          content_filter = :content_a_id
        else
          relation_name = :content_b
          relation_a_name = relation_a
          relation_b_name = relation_b
          content_filter = :content_b_id
        end

        content_contents_condition = {
          relation_a: relation_a_name,
          relation_b: relation_b_name
        }
        content_contents_condition[content_filter] = filter.apply(skip_ordering: true).select(:id).except(:order) if filter.present?

        relation_contents = self.class.unscoped do
          send(relation_name).where(content_contents: content_contents_condition).i18n
        end

        relation_contents = relation_contents.joins(:translations).where(thing_translations: { locale: languages }) if same_language
        relation_contents
      end

      def load_classifications(relation_name, _overlay_flag = false)
        classification_content.with_relation(relation_name).classifications
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name(tree_label, alias_name)
      end

      def load_asset_relation(relation_name)
        DataCycleCore::Asset.joins(:asset_content)
          .where(asset_contents: { content_data_id: id, relation: relation_name })
      end

      def load_schedule(relation_name, _overlay_flag = false)
        DataCycleCore::Schedule.where(thing_id: id, relation: relation_name).order(created_at: :asc)
      end

      def load_timeseries(property_name)
        DataCycleCore::Timeseries.where(thing_id: id, property: property_name).order(timestamp: :asc)
      end

      def load_collections(property_name)
        DataCycleCore::Collection.joins(:content_collection_links).where(content_collection_links: { thing_id: id, relation: property_name }).order(order_a: :asc)
      end

      def as_of(timestamp)
        timestamp = timestamp.in_time_zone if timestamp.is_a?(::String)

        return self if updated_at.blank? || timestamp.blank? || timestamp >= updated_at

        history = histories
          .includes(:translations)
          .where(translations: { locale: first_available_locale })
          .find_by('thing_histories.updated_at <= ?', timestamp)

        return history unless history.nil?

        first_history = histories
          .includes(:translations)
          .where(translations: { locale: first_available_locale })
          .last

        return if first_history.nil? || timestamp < first_history.created_at

        first_history
      end
    end
  end
end
