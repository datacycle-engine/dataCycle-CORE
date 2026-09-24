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

      def diff(data, template = nil, partial_update = true)
        diff_obj(data, template, partial_update).diff_hash
      end

      def diff_obj(data, template = nil, partial_update = true)
        differ = DataCycleCore::MasterData::DiffData.new
        if template.present?
          differ.diff(a: get_data_hash_partial(data.keys), schema_a: template, b: data, schema_b: template, partial_update:)
        else
          differ.diff(a: get_data_hash, schema_a: schema, b: data, schema_b: template, partial_update:)
        end
      end

      def diff?(data, template = nil, partial_update = true)
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

        relation_b = properties['inverse_of']
        language_flag = same_language
        language_flag = properties['linked_language'] == 'same' if properties['linked_language'].present?
        load_relation(relation_name, relation_b, language_flag, languages, filter, properties['link_direction'] == 'inverse', overlay_flag)
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
        else
          relation_name = :content_b
          relation_a_name = relation_a
          relation_b_name = relation_b
        end

        content_contents_condition = {
          relation_a: relation_a_name,
          relation_b: relation_b_name
        }

        relation_contents = self.class.unscoped do
          send(relation_name).where(content_contents: content_contents_condition).i18n.includes(:thing_template)
        end

        relation_contents = relation_contents.with_translation(languages) if same_language

        filter_contents(relation_contents, filter)
      end

      # Concept.default_scope supplies the ORDER BY here; concept_contents carries no order column of
      # its own, so without it Postgres may hand the rows back in a new order once anything writes to
      # the table, and the sync_api serializes that as a changed value - the consuming instance then
      # re-imports content that did not change.
      def load_classifications(relation_name, _overlay_flag = false)
        rel = concepts.where(concept_contents: { relation: relation_name })

        return rel unless concept_contents.loaded?

        # the association autosaves, so a loaded target may hold rows a classification setter marked
        # for destruction (Attributes::ClassificationAttributes) - gone on save, so not part of the value
        rows = concept_contents.select { |cc| cc.relation == relation_name && !cc.marked_for_destruction? }

        # only a preload (concept_contents: :concept) has the concepts at hand;
        # a setter loading the rows on its own does not, and reading them here would be one query per row
        return rel unless rows.all? { |cc| cc.association(:concept).loaded? }

        # Concept.default_scope's ORDER BY never runs on this branch, so replay it here - Postgres
        # sorts a NULL order_a last on ASC - and the two branches hand back the same order.
        rel.tap { |r| r.send(:load_records, rows.filter_map(&:concept).sort_by { |c| [c.order_a || Float::INFINITY, c.id] }) }
      end

      def load_default_classification(tree_label, alias_name)
        DataCycleCore::Concept.id_for_tree_with_name(tree_label, alias_name)
      end

      def load_asset_relation(relation_name)
        rel = assets.where(asset_contents: { thing_id: id, relation: relation_name })

        if asset_contents.loaded?
          loaded_records = asset_contents.select { |ac| ac.relation == relation_name }.filter_map(&:asset)
          rel.tap { |r| r.send(:load_records, loaded_records) }
        end

        rel
      end

      def load_schedule(relation_name, _overlay_flag = false)
        rel = schedules.where(relation: relation_name).order(created_at: :asc)

        if schedules.loaded?
          loaded_records = schedules.select { |s| s.relation == relation_name }.sort_by(&:created_at)
          rel.tap { |r| r.send(:load_records, loaded_records) }
        end

        rel
      end

      def load_timeseries(property_name)
        rel = timeseries.where(property: property_name).order(timestamp: :asc)

        if timeseries.loaded?
          loaded_records = timeseries.select { |t| t.property == property_name }.sort_by(&:timestamp)
          rel.tap { |r| r.send(:load_records, loaded_records) }
        end

        rel
      end

      def load_collections(property_name)
        rel = DataCycleCore::Collection.includes(:content_collection_links)
          .where(content_collection_links: { thing_id: id, relation: property_name })
          .order(order_a: :asc)

        if content_collection_links.loaded?
          loaded_records = content_collection_links.select { |ccl| ccl.relation == property_name }
            .sort_by(&:order_a)
            .filter_map(&:collection)
          rel.tap { |r| r.send(:load_records, loaded_records) }
        end

        rel
      end

      def filter_contents(contents, filter)
        return contents if filter.nil? || contents.blank?

        filtered_contents = contents.to_a.filter { |c| filter.cached.thing_ids_nested.include?(c.id) }

        contents.where(id: filtered_contents.pluck(:id))
          .tap { |rel| rel.send(:load_records, filtered_contents) }
      end

      def load_geometry(property_name)
        geometries.detect { |g| g.relation == property_name }&.geom
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
