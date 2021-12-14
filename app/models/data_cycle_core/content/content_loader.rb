# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentLoader
      def get_data_hash(timestamp = Time.zone.now)
        as_of(timestamp).try(:to_h, timestamp)
      end

      def get_data_hash_partial(keys, timestamp = Time.zone.now)
        as_of(timestamp).try(:to_h_partial, keys, timestamp)
      end

      def diff(data, template = nil, partial_update = false)
        # differ = DataCycleCore::MasterData::DiffData.new
        # if template.present?
        #   # differ.diff(a: get_data_hash&.slice(*data.keys), schema_a: template, b: data, schema_b: template, partial_update: partial_update).diff_hash
        #   differ.diff(a: get_data_hash_partial(data.keys), schema_a: template, b: data, schema_b: template, partial_update: partial_update).diff_hash
        # else
        #   differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template, partial_update: partial_update).diff_hash
        # end
        diff_obj(data, template, partial_update).diff_hash
      end

      def diff_obj(data, template = nil, partial_update = false)
        differ = DataCycleCore::MasterData::DiffData.new
        if template.present?
          # differ.diff(a: get_data_hash&.slice(*data.keys), schema_a: template, b: data, schema_b: template, partial_update: partial_update).diff_hash
          differ.diff(a: get_data_hash_partial(data.keys), schema_a: template, b: data, schema_b: template, partial_update: partial_update)
        else
          differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template, partial_update: partial_update)
        end
      end

      def diff?(data, template = nil, partial_update = false)
        differ = DataCycleCore::MasterData::DiffData.new
        if template.present?
          # byebug
          # differ.diff?(a: get_data_hash&.slice(*data.keys), schema_a: template, b: data, schema_b: template, partial_update: partial_update)
          differ.diff?(a: get_data_hash_partial(data.keys), schema_a: template, b: data, schema_b: template, partial_update: partial_update)
        else
          differ.diff?(a: get_data_hash, schema_a: schema, b: data, schema_b: template, partial_update: partial_update)
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

      def load_relation(relation_a, relation_b, same_language, languages, filter = nil, inverse = false, overlay_flag = false)
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

        overwritten = overlay_data(I18n.locale).try(:[], relation_a) if overlay_flag
        root_object = overwritten.present? ? overlay.first : self

        content_contents_condition = {
          relation_a: relation_a_name,
          relation_b: relation_b_name
        }
        content_contents_condition[content_filter] = filter.apply.select(:id).except(:order) if filter.present?

        relation_contents = self.class.unscoped do
          root_object.send(relation_name).where(content_contents: content_contents_condition).i18n
        end

        relation_contents = relation_contents.joins(:translations).where(thing_translations: { locale: languages }) if same_language
        relation_contents
      end

      def load_classifications(relation_name, overlay_flag = false)
        value = overlay_data(I18n.locale).try(:[], relation_name) if overlay_flag
        content_data_id = value.present? ? overlay_data(I18n.locale).dig('id') : id
        DataCycleCore::Classification
          .joins(:classification_contents)
          .where(
            classification_contents: {
              content_data_id: content_data_id, relation: relation_name
            }
          )
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::ClassificationAlias.classification_for_tree_with_name(tree_label, alias_name)
      end

      def load_asset_relation(relation_name)
        DataCycleCore::Asset.joins(:asset_content)
          .where(asset_contents: { content_data_id: id, relation: relation_name })
      end

      def load_schedule(relation_name, overlay_flag = false)
        value = overlay_data(I18n.locale).try(:[], relation_name) if overlay_flag
        thing_id = value.present? ? overlay_data(I18n.locale).dig('id') : id
        DataCycleCore::Schedule.where(thing_id: thing_id, relation: relation_name).order(created_at: :asc)
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
        )
          .where(history_table_translation[:locale].eq(first_available_locale))
          .where(in_range(history_table_translation, timestamp))
          .order(history_table_translation[:history_valid])

        return_data.last
      end
    end
  end
end
