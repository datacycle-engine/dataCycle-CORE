# frozen_string_literal: true

raise 'ActiveRecord::Relation#load_records is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load_records
raise 'ActiveRecord::Relation#load_records arity != 1, check patch!' unless ActiveRecord::Relation.instance_method(:load_records).arity == 1

module DataCycleCore
  module Content
    module Extensions
      module SyncApi
        extend ActiveSupport::Concern

        def to_sync_data(locales: nil, translated: false, preloaded: {}, ancestor_ids: [], included: [], classifications: [], attribute_name: nil, linked_stored_filter: nil)
          ancestor_proc = ->(a) { a[:id] == id }

          return if ancestor_ids.count(&ancestor_proc) >= 2

          languages = available_locales.presence || [I18n.locale]
          languages = locales if locales.present? && translated
          new_ancestor_ids = ancestor_ids + [{ id:, attribute_name: }]
          preloaded = preload_sync_data(linked_stored_filter:) if preloaded.blank?

          data = languages.index_with do |lang|
            Rails.cache.fetch("sync_api_v1_show/#{self.class.name.underscore}/#{id}_#{lang}_#{updated_at.to_i}_#{cache_valid_since.to_i}", expires_in: 1.year + Random.rand(7.days)) do
              I18n.with_locale(lang) { to_sync_h(locales:, preloaded:, ancestor_ids: new_ancestor_ids, included:, classifications:, linked_stored_filter:) }
            end
          end

          data = data.with_indifferent_access

          unless embedded?
            if attribute_name.present?
              data[:attribute_name] = [attribute_name]
              included.unshift(data)
            end
            add_sync_included_data(data:, preloaded:, ancestor_ids: new_ancestor_ids, included:, classifications:, locales: languages, linked_stored_filter:)
          end

          if ancestor_ids.any?(&ancestor_proc)
            data['recursive'] = ancestor_ids.reject(&ancestor_proc).filter { |a| a[:attribute_name]&.in?(data[languages.first].keys) }.uniq
            return data
          end

          if new_ancestor_ids.size == 1
            data[:included] = included
            data[:classifications] = classifications
          end

          data
        end

        def to_sync_h(locales: nil, preloaded: {}, ancestor_ids: [], included: [], classifications: [], linked_stored_filter: nil)
          (property_names - timeseries_property_names)
            .index_with { |key| attribute_to_sync_h(key, locales:, preloaded:, ancestor_ids:, included:, classifications:, linked_stored_filter:) }
            .merge(sync_metadata)
            .tap { |sync_data| sync_data['universal_classifications'] += attribute_to_sync_h('mapped_classifications', locales:, preloaded:, ancestor_ids:, included:, classifications:, linked_stored_filter:) }
            .deep_stringify_keys
        end

        def attribute_to_sync_h(property_name, locales: nil, preloaded: {}, ancestor_ids: [], included: [], classifications: [], linked_stored_filter: nil)
          present_overlay = overlay_property_names.include?(property_name)
          property_name_with_overlay = property_name
          property_name_with_overlay = "#{property_name}_#{overlay_name}" if overlay_property_names.include?(property_name) && property_name != 'id'

          if plain_property_names.include?(property_name)
            send(property_name_with_overlay)&.as_json
          elsif classification_property_names.include?(property_name)
            send(property_name_with_overlay).try(:pluck, :id)
          elsif linked_property_names.include?(property_name)
            return [] if properties_for(property_name)['link_direction'] == 'inverse'

            get_property_value(property_name, property_definitions[property_name], linked_stored_filter, present_overlay).pluck(:id) || []
          elsif included_property_names.include?(property_name)
            embedded_hash = send(property_name_with_overlay).to_h
            embedded_hash.presence
          elsif embedded_property_names.include?(property_name)
            return if property_name == overlay_name
            translated = properties_for(property_name)['translated']
            embedded_array = send(property_name_with_overlay)

            translated = property_definitions[property_name]['translated']
            embedded_array&.map { |i| i.to_sync_data(translated:, locales:, preloaded:, ancestor_ids:, included:, classifications:, attribute_name: property_name, linked_stored_filter:) }&.compact || []
          elsif asset_property_names.include?(property_name)
          # send(property_name_with_overlay) # do nothing --> only import url not asset itself
          elsif schedule_property_names.include?(property_name)
            schedule_array = send(property_name_with_overlay)

            schedule_array&.map { |schedule| schedule.to_h.except(:thing_id) }&.compact || []
          elsif property_name == 'mapped_classifications'
            classification_property_names&.map { |classification_property_name|
              classification_property_name_overlay = classification_property_name
              classification_property_name_overlay = "#{classification_property_name}_#{overlay_name}" if overlay_property_names.include?(classification_property_name)
              send(classification_property_name_overlay)&.map { |classification|
                mapped_ids = classification.additional_classification_aliases.map(&:id)
                preloaded['classifications']
                  &.filter { |_k, v| v[:classification_alias_id].in?(mapped_ids) }
                  &.keys
              }.presence&.flatten
            }&.compact&.flatten
          else
            raise StandardError, "Can not determine how to serialize #{property_name} for sync_api."
          end
        end

        def add_sync_included_data(data:, preloaded:, ancestor_ids:, included:, classifications:, locales:, linked_stored_filter: nil)
          data&.each_value do |translation|
            translation&.each do |key, value|
              if embedded_property_names.include?(key) && value.present?
                value.each do |v|
                  embedded_id = v&.values&.first&.dig('id')
                  next if embedded_id.nil?
                  new_ancestor_ids = ancestor_ids + [{ id: embedded_id, attribute_name: key }]

                  preloaded.dig('contents', embedded_id)&.add_sync_included_data(data: v, preloaded:, ancestor_ids: new_ancestor_ids, included:, classifications:, locales:, linked_stored_filter:)
                end

                next
              end

              if linked_property_names.include?(key) && value.present?
                value.each do |linked_id|
                  existing = included.detect { |item| locales.any? { |l| item.dig(l.to_s, 'id') == linked_id } }

                  if existing.present?
                    existing[:attribute_name].push(key) unless existing[:attribute_name].include?(key)
                  else
                    preloaded.dig('contents', linked_id)&.to_sync_data(preloaded:, ancestor_ids:, included:, classifications:, attribute_name: key, linked_stored_filter:)
                  end
                end
              end

              if classification_property_names.include?(key) && value.present?
                value.each do |classification_id|
                  existing = classifications.detect { |c| c['id'] == classification_id }
                  c_data = preloaded.dig('classifications', classification_id)

                  next if c_data.blank?

                  if existing.present?
                    existing['attribute_name'].push(key) unless existing['attribute_name'].include?(key)
                  else
                    classifications.unshift(
                      c_data[:classification_hash]&.merge({
                        'ancestors' => c_data[:ancestors],
                        'attribute_name' => [key]
                      })
                    )
                  end

                  mapped_ids = c_data[:classification].additional_classification_aliases.map(&:id)

                  preloaded['classifications']
                    .each_value do |v|
                      next unless mapped_ids.include?(v[:classification_alias_id])

                      existing = classifications.detect { |c| c['id'] == v.dig(:classification_hash, 'id') }

                      if existing.present?
                        existing['attribute_name'].push('universal_classifications') unless existing['attribute_name'].include?('universal_classifications')
                      else
                        classifications.unshift(
                          v[:classification_hash]&.merge({
                            'ancestors' => v[:ancestors],
                            'attribute_name' => ['universal_classifications']
                          })
                        )
                      end
                    end
                end
              end
            end
          end
        end

        def sync_metadata
          sm = {
            template_name:,
            updated_at:,
            created_at:,
            external_key:,
            external_source_id:,
            external_source: external_source&.identifier
          }
          unless embedded?
            sm = sm.merge({
              last_sync_at: updated_at,
              last_successful_sync_at: updated_at,
              status: 'success',
              external_system_syncs: external_system_syncs.map { |i|
                {
                  'external_key' => i.external_key || id,
                  'status' => i.status,
                  'last_sync_at' => i.last_sync_at,
                  'sync_type' => 'duplicate',
                  'last_successful_sync_at' => i.last_successful_sync_at,
                  'name' => i.external_system&.identifier
                }
              }.compact
            })
          end
          sm
        end

        def to_sync_api_deleted
          {
            'id' => id,
            'deleted_at' => deleted_at
          }
        end

        def preload_sync_data(linked_stored_filter: nil)
          DataCycleCore::Thing.unscoped.where(id:).tap { |rel| rel.send(:load_records, [self]) }.preload_sync_data(linked_stored_filter:).last
        end

        class_methods do
          def preload_sync_data(linked_stored_filter: nil)
            content_ids = all.pluck(:id)

            return [], {} if content_ids.blank?

            preloaded_content_contents = all
              .recursive_content_content_a
              .select(:content_a_id, :relation_a, :content_b_id)

            if linked_stored_filter.present?
              sub_query = <<-SQL.squish
                things.content_type = 'embedded'
                OR EXISTS (#{linked_stored_filter.apply(skip_ordering: true).except(:order).select(1).where('things.id = content_contents.content_b_id').to_sql})
              SQL
              preloaded_content_contents = preloaded_content_contents.joins(:content_b).where(send(:sanitize_sql_array, [sub_query]))
            end
            preloaded_content_contents = preloaded_content_contents.to_a

            preloaded = {}
            preloaded['contents'] = DataCycleCore::Thing
              .default_scoped
              .includes(:thing_template)
              .where(id: content_ids + preloaded_content_contents.pluck(:content_b_id))
              .preload(
                :translations,
                :external_source,
                :classification_content,
                :schedules,
                external_system_syncs: [:external_system],
                asset_contents: [:asset],
                collected_classification_contents: [classification_alias: [:external_source, :classification_alias_path, classification_tree_label: [:external_source], primary_classification: [:external_source, :additional_classification_aliases]]]
              )
              .index_by(&:id)

            preloaded['content_contents'] = preloaded_content_contents.group_by(&:content_a_id).transform_values! { |v| v.group_by(&:relation_a).transform_values! { |cc| cc.map(&:content_b_id) } }
            overlay_templates = DataCycleCore::ThingTemplate.where(template_name: preloaded['contents'].values.map(&:overlay_template_name).uniq).index_by(&:template_name)
            collected_classification_contents = preloaded['contents'].values.map!(&:collected_classification_contents).flatten!
            classification_aliases = collected_classification_contents&.map(&:classification_alias)&.index_by(&:id) || {}
            full_classification_aliases = classification_aliases.merge(
              DataCycleCore::ClassificationAlias
                .where(id: classification_aliases.values.map(&:classification_alias_path).map!(&:ancestor_ids).flatten!)
                .where.not(id: classification_aliases.keys)
                .index_by(&:id)
            )
            preloaded['classifications'] = collected_classification_contents&.map { |ccc|
              next if ccc.classification_alias.primary_classification.nil?

              {
                classification: ccc.classification_alias.primary_classification,
                classification_alias_id: ccc.classification_alias.id,
                classification_hash: ccc.classification_alias.primary_classification.as_json(
                  only: [:id, :name, :external_source_id, :external_key, :description, :uri]
                )
                  .merge({
                    'class_type' => 'DataCycleCore::Classification',
                    'external_system' => ccc.classification_alias.primary_classification.external_source&.identifier
                  }),
                ancestors: full_classification_aliases
                  .values_at(*ccc.classification_alias.classification_alias_path.full_path_ids)
                  .map { |ca|
                    ca.as_json(only: [:id, :internal_name, :external_source_id, :external_key, :name_i18n, :description_i18n, :uri], include: { primary_classification: { only: [:id, :name, :external_source_id, :external_key, :description, :uri] } })
                    .merge({
                      'class_type' => 'DataCycleCore::ClassificationAlias',
                      'external_system' => ca.external_source&.identifier
                    })
                  } +
                  [
                    ccc.classification_alias.classification_tree_label.as_json(only: [:id, :name]).merge({
                      'class_type' => 'DataCycleCore::ClassificationTreeLabel',
                      'external_system' => ccc.classification_alias.classification_tree_label&.external_source&.identifier
                    })
                  ]
              }
            }&.compact&.index_by { |v| v[:classification].id } || {}

            preloaded['classification_contents'] = preloaded['contents'].values.map!(&:classification_content).flatten!.group_by(&:content_data_id).transform_values! { |v| v.group_by(&:relation).transform_values! { |cc| cc.map(&:classification_id) } }
            preloaded['full_classifications'] = collected_classification_contents.group_by(&:thing_id).transform_values! do |v|
              v.map { |ccc| ccc.classification_alias.primary_classification&.id }.compact
            end

            preloaded['contents'].each_value do |content|
              I18n.with_locale(content.first_available_locale) do
                content.instance_variable_set(:@overlay_property_names, content.overlay_template_name.present? ? Array.wrap(overlay_templates[content.overlay_template_name]&.property_names) : [])
                if content.overlay_allowed?
                  content.set_memoized_attribute(
                    content.overlay_name,
                    preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, content.overlay_name)) || []
                  )
                end

                # used only for virtual thumbnail url
                content.asset_property_names.each do |k|
                  content.set_memoized_attribute(k, content.asset_contents.detect { |ac| ac.relation == k }&.asset)
                end
                content.schedule_property_names.each do |k|
                  content.set_memoized_attribute(
                    k,
                    content.overlay_property_names.include?(k) ? content.overlay_content&.schedules&.filter { |schedule| schedule.relation == k }.presence || content.schedules.filter { |schedule| schedule.relation == k } : content.schedules.filter { |schedule| schedule.relation == k },
                    nil,
                    content.overlay_property_names.include?(k)
                  )
                end

                content.classification_property_names.each do |k|
                  content.set_memoized_attribute(
                    k,
                    content.overlay_property_names.include?(k) ? preloaded['classifications'].values_at(*preloaded.dig('classification_contents', content.overlay_content&.id, k)).pluck(:classification).presence || preloaded['classifications'].values_at(*preloaded.dig('classification_contents', content.id, k)).pluck(:classification) : preloaded['classifications'].values_at(*preloaded.dig('classification_contents', content.id, k)).pluck(:classification),
                    nil,
                    content.overlay_property_names.include?(k)
                  )
                end

                content.linked_property_names.each do |k|
                  content.set_memoized_attribute(
                    k,
                    content.overlay_property_names.include?(k) ? preloaded['contents'].values_at(*preloaded.dig('content_contents', content.overlay_content&.id, k)).presence || preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, k)) : preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, k)),
                    linked_stored_filter,
                    content.overlay_property_names.include?(k)
                  )
                end

                content.embedded_property_names.each do |k|
                  if content.translatable_property?(k)
                    content.available_locales.each do |locale|
                      I18n.with_locale(locale) do
                        content.set_memoized_attribute(
                          k,
                          content.overlay_property_names.include?(k) ? preloaded['contents'].values_at(*preloaded.dig('content_contents', content.overlay_content&.id, k)).filter { |t| t&.translated_locales&.include?(locale) }.presence || preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, k)).filter { |t| t&.translated_locales&.include?(locale) } : preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, k)).filter { |t| t&.translated_locales&.include?(locale) },
                          nil,
                          content.overlay_property_names.include?(k)
                        )
                      end
                    end
                  else
                    content.set_memoized_attribute(
                      k,
                      content.overlay_property_names.include?(k) ? preloaded['contents'].values_at(*preloaded.dig('content_contents', content.overlay_content&.id, k)).presence || preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, k)) : preloaded['contents'].values_at(*preloaded.dig('content_contents', content.id, k)),
                      nil,
                      content.overlay_property_names.include?(k)
                    )
                  end
                end
              end
            end

            return preloaded['contents'].values_at(*content_ids), preloaded
          end

          def to_sync_data(linked_stored_filter: nil)
            things, preloaded = all.preload_sync_data(linked_stored_filter:)

            things.map do |content|
              content.to_sync_data(
                locales: content.available_locales,
                preloaded:,
                linked_stored_filter:
              )
            end
          end
        end
      end
    end
  end
end
