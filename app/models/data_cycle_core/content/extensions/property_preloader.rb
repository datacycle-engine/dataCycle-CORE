# frozen_string_literal: true

raise 'ActiveRecord::Relation#load_records is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load_records
raise 'ActiveRecord::Relation#load_records arity != 1, check patch!' unless ActiveRecord::Relation.instance_method(:load_records).arity == 1

module DataCycleCore
  module Content
    module Extensions
      module PropertyPreloader
        def current_collection?
          !@_current_collection.nil?
        end

        def current_recursive_collection?
          !@_current_recursive_collection.nil?
        end

        def current_rc_with_leafs?
          !@_current_rc_with_leafs.nil?
        end

        private

        def preload_property(property_name, filter, overlay_flag)
          return self unless current_collection?
          return self if @get_property_value&.key?(attibute_cache_key(property_name, filter, overlay_flag))
          return self if virtual_property_names.include?(property_name)

          preload_current_recursive_collection if overlay_flag || relation_property_names.include?(property_name)

          return self unless current_recursive_collection?

          preload_overlays if overlay_flag || embedded_property_names.include?(property_name) || linked_property_names.include?(property_name)
          preload_linked_properties(filter) if linked_property_names.include?(property_name)
          preload_embedded_properties if embedded_property_names.include?(property_name)
          preload_classification_properties if classification_property_names.include?(property_name)
          preload_asset_properties if asset_property_names.include?(property_name)
          preload_schedule_properties if schedule_property_names.include?(property_name)

          self
        end

        def add_preloaded_ccs(cc, a_key = :content_a_id, relation_key = :relation_a, b_key = :content_b_id)
          key_a = cc.send(a_key)
          relation_name = cc.send(relation_key)

          @_current_recursive_ccs ||= {}
          @_current_recursive_ccs[key_a] ||= {}
          @_current_recursive_ccs[key_a][relation_name] ||= []
          @_current_recursive_ccs[key_a][relation_name].push(cc.send(b_key))
        end

        def preload_current_recursive_collection
          return if current_recursive_collection?

          current_contents = @_current_collection.to_a
          content_ids = current_contents.pluck(:id)
          depth = @_current_collection.instance_variable_get(:@_recursive_preload_depth)
          depth ||= current_contents.first.instance_variable_get(:@_recursive_preload_depth) if current_contents.size == 1
          preloaded_ccs = @_current_collection.recursive_content_links(depth: depth || 1).to_a
          ids_to_preload = []
          leaf_ids = []

          preloaded_ccs.each do |cc|
            cc.leaf ? leaf_ids.push(cc.content_b_id) : ids_to_preload.push(cc.content_b_id)
            add_preloaded_ccs(cc)

            next if cc.relation_b.blank?

            cc.leaf ? leaf_ids.push(cc.content_a_id) : ids_to_preload.push(cc.content_a_id)
            add_preloaded_ccs(cc, :content_b_id, :relation_b, :content_a_id)
          end

          additional_contents = self.class
            .default_scoped
            .where(id: ids_to_preload + leaf_ids)
            .where.not(id: content_ids)
            .to_a

          leaf_contents = self.class
            .default_scoped
            .where(id: leaf_ids)
          leaf_contents.send(:load_records, additional_contents.filter { |c| ids_to_preload.exclude?(c.id) })

          current_rc_with_leafs = self.class
            .default_scoped
            .where(id: content_ids + ids_to_preload + leaf_ids)
          current_rc_with_leafs.send(:load_records, (current_contents + additional_contents).uniq)
          @_current_rc_with_leafs = current_rc_with_leafs.index_by(&:id)

          values_to_preload = @_current_rc_with_leafs.values_at(*ids_to_preload)
          values_to_preload.compact!

          @_current_recursive_collection = self.class
            .default_scoped
            .where(id: content_ids + ids_to_preload)
          @_current_recursive_collection.send(:load_records, (current_contents + values_to_preload).uniq)

          ActiveRecord::Associations::Preloader.new.preload(@_current_rc_with_leafs.values, :translations)

          leaf_contents.each do |content|
            content.instance_variable_set(:@_current_collection, leaf_contents)
          end

          @_current_recursive_collection.each do |content|
            content.instance_variable_set(:@_current_recursive_collection, @_current_recursive_collection)
            content.instance_variable_set(:@_current_rc_with_leafs, @_current_rc_with_leafs)
            content.instance_variable_set(:@_current_recursive_ccs, @_current_recursive_ccs)
            content.content_content_a.send(:load_records, preloaded_ccs.filter { |cc| cc.content_a_id = content.id })
            content.content_content_b.send(:load_records, preloaded_ccs.filter { |cc| cc.content_b_id = content.id })
          end
        end

        def preload_overlays
          return if @_current_recursive_collection.instance_variable_get(:@_overlays_preloaded) || @_current_recursive_collection.all? { |c| c.instance_variable_get(:@_overlay_preloaded) }

          overlay_templates = DataCycleCore::ThingTemplate.where(template_name: @_current_recursive_collection.map(&:overlay_template_name).compact.uniq).to_h { |tt| [tt.template_name, Array.wrap(tt.property_names)] }

          @_current_recursive_collection.each do |content|
            content.instance_variable_set(:@_overlay_preloaded, true)
            content.instance_variable_set(:@overlay_property_names, content.overlay_template_name.present? ? overlay_templates[content.overlay_template_name] : [])

            next unless content.overlay_allowed?

            related_contents = @_current_rc_with_leafs&.values_at(*@_current_recursive_ccs&.dig(content.id, content.overlay_name))

            if content.translatable_property?(content.overlay_name)
              content.available_locales.each do |locale|
                I18n.with_locale(locale) do
                  related_contents = related_contents&.filter { |t| t&.translated_locales&.include?(locale) }

                  content.set_memoized_attribute(content.overlay_name, related_contents, nil, false)
                end
              end
            else
              content.set_memoized_attribute(content.overlay_name, related_contents, nil, false)
            end
          end

          @_current_recursive_collection.instance_variable_set(:@_overlays_preloaded, true)
        end

        def preload_embedded_properties
          @_current_recursive_collection.each do |content|
            content.embedded_property_names.each do |k|
              next if k == 'overlay' || content.virtual_property_names.include?(k)

              related_contents = @_current_rc_with_leafs&.values_at(*@_current_recursive_ccs&.dig(content.id, k))
              overlay_related_contents = @_current_rc_with_leafs&.values_at(*@_current_recursive_ccs&.dig(content.overlay_content&.id, k)) if content.overlay_property_names.include?(k)

              if content.translatable_property?(k)
                content.available_locales.each do |locale|
                  I18n.with_locale(locale) do
                    i18n_related_contents = related_contents&.filter { |t| t&.translated_locales&.include?(locale) }
                    i18n_overlay_related_contents = overlay_related_contents&.filter { |t| t&.translated_locales&.include?(locale) }

                    content.set_memoized_attribute(k, i18n_overlay_related_contents.presence || i18n_related_contents, nil, true) if content.overlay_property_names.include?(k)
                    content.set_memoized_attribute(k, i18n_related_contents, nil, false)
                  end
                end
              else
                content.set_memoized_attribute(k, overlay_related_contents.presence || related_contents, nil, true) if content.overlay_property_names.include?(k)
                content.set_memoized_attribute(k, related_contents, nil, false)
              end
            end
          end
        end

        def preload_linked_properties(filter)
          collection_with_leafs = @_current_rc_with_leafs
          collection_with_leafs = collection_with_leafs&.slice(*filter.apply(skip_ordering: true).query.reorder(nil).pluck(:id)) if filter.present?

          @_current_recursive_collection.each do |content|
            content.linked_property_names.each do |k|
              next if content.virtual_property_names.include?(k)
              related_contents = collection_with_leafs&.values_at(*@_current_recursive_ccs&.dig(content.id, k))
              related_contents&.compact!

              if content.overlay_property_names.include?(k)
                overlay_related_contents = collection_with_leafs&.values_at(*@_current_recursive_ccs&.dig(content.overlay_content&.id, k))
                overlay_related_contents&.compact!

                content.set_memoized_attribute(k, overlay_related_contents.presence || related_contents, filter, true)
              end

              content.set_memoized_attribute(k, related_contents, filter, false)
            end
          end
        end

        def preload_classification_properties
          classifications = @_current_recursive_collection.collected_classification_contents(preload: [classification_alias: [:primary_classification, :classification_alias_path, :classification_tree_label]]).flat_map(&:classification_alias).flat_map(&:primary_classification).uniq.index_by(&:id)
          classification_contents = @_current_recursive_collection.classification_contents(preload: true).group_by(&:content_data_id).transform_values! { |v| v.group_by(&:relation).transform_values! { |cc| cc.map(&:classification_id) } }

          @_current_recursive_collection.each do |content|
            content.classification_property_names.each do |k|
              next if content.virtual_property_names.include?(k)
              classification_values = classifications.values_at(*classification_contents.dig(content.id, k))

              if content.overlay_property_names.include?(k)
                overlay_classification_values = classifications.values_at(*classification_contents.dig(content.overlay_content&.id, k))
                content.set_memoized_attribute(k, overlay_classification_values.presence || classification_values, nil, true)
              end

              content.set_memoized_attribute(k, classification_values, nil, false)
            end
          end
        end

        def preload_asset_properties
          asset_contents = @_current_recursive_collection.asset_contents(preload: :asset)
          acs = asset_contents.group_by(&:content_data_id).transform_values! { |v| v.group_by(&:relation).transform_values! { |ac| ac.map(&:asset_id) } }
          assets = asset_contents.flat_map(&:asset).index_by(&:id)

          @_current_recursive_collection.each do |content|
            content.asset_property_names.each do |k|
              next if content.virtual_property_names.include?(k)
              asset_values = assets.values_at(*acs.dig(content.id, k)).first

              if content.overlay_property_names.include?(k)
                overlay_asset_values = assets.values_at(*acs.dig(content.overlay_content&.id, k)).first
                content.set_memoized_attribute(k, overlay_asset_values || asset_values, nil, true)
              end

              content.set_memoized_attribute(k, asset_values, nil, false)
            end
          end
        end

        def preload_schedule_properties
          schedule_data = @_current_recursive_collection.schedules(preload: true).order(created_at: :asc).group_by(&:thing_id).transform_values! { |v| v.group_by(&:relation) }

          @_current_recursive_collection.each do |content|
            content.schedule_property_names.each do |k|
              next if content.virtual_property_names.include?(k)
              schedule_values = schedule_data.dig(content.id, k)

              if content.overlay_property_names.include?(k)
                overlay_schedule_values = schedule_data.dig(content.overlay_content&.id, k)
                content.set_memoized_attribute(k, overlay_schedule_values || schedule_values, nil, true)
              end

              content.set_memoized_attribute(k, schedule_values, nil, false)
            end
          end
        end

        def preload_timeseries_properties
          timeseries_data = @_current_recursive_collection.timeseries(preload: true).order(timestamp: :asc).group_by(&:thing_id).transform_values! { |v| v.group_by(&:property) }

          @_current_recursive_collection.each do |content|
            content.timeseries_property_names.each do |k|
              next if content.virtual_property_names.include?(k)
              timeseries_values = timeseries_data.dig(content.id, k)

              if content.overlay_property_names.include?(k)
                overlay_timeseries_values = timeseries_data.dig(content.overlay_content&.id, k)
                content.set_memoized_attribute(k, overlay_timeseries_values || timeseries_values, nil, true)
              end

              content.set_memoized_attribute(k, timeseries_values, nil, false)
            end
          end
        end
      end
    end
  end
end
