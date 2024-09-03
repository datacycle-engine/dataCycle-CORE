# frozen_string_literal: true

module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters(view:, user:, selected_filters:)
          config = configuration.dig(:config, view).deep_dup || {}
          config[:view_type] = view
          config[:hidden_filter] = []
          config[:excluded_types] = DataCycleCore.excluded_filter_classifications

          transform_filter_configs!(config[:filter] ||= [], user, view)
          merge_filter_values!(user, config, Array.wrap(selected_filters))

          config[:sortable] = DataCycleCore::Feature::Sortable.available_options(user, view) if config[:sortable].present?

          config
        end

        def transform_filter_configs!(filters, user, view)
          filters
            .map! { |filter|
              k, v = filter.first
              next unless v.present? && user.can?(k.to_sym, view.to_sym, v)

              {
                type: k,
                config: v
              }
            }
            .compact!
        end

        def merge_filter_values!(user, config, selected_filters)
          classification_trees_filters(user, config, selected_filters) unless config[:view_type] == 'users'
          search_filters(user, config, selected_filters)
          advanced_filters(user, config, selected_filters)
          advanced_filters(user, config, selected_filters, :permanent_advanced, 'p', false)
          classification_tree_filters(user, config, selected_filters)
          advanced_user_filters(user, config, selected_filters)

          return unless config[:view_type] == 'users'

          user_dropdown_filters(user, config, selected_filters)
          user_advanced_filters(user, config, selected_filters)
        end

        def user_dropdown_filters(_user, config, selected_filters)
          user_dropdown_filter = config[:filter].find { |v| v[:type] == 'user_dropdown' }
          return if user_dropdown_filter.blank?

          user_dropdown_filter[:config].each do |name|
            value = selected_filters.find { |f| f['c'] == 'd' && f['n'] == name }
            user_dropdown_filter[:filters] ||= {}
            user_dropdown_filter[:filters][name] = {
              value: value&.dig('v'),
              identifier: value&.dig('identifier') || SecureRandom.hex(10)
            }
          end
        end

        def user_advanced_filters(_user, config, selected_filters)
          advanced_filter = config[:filter].find { |v| v[:type] == 'user_advanced' }
          return if advanced_filter.blank?

          advanced_filter[:filters] = selected_filters.select { |f| f['c'] == 'a' }
          advanced_filter[:filters].each do |filter|
            filter['buttons'] = true
          end
        end

        def classification_trees_filters(_user, config, selected_filters)
          classification_filter = config[:filter].find { |v| v[:type] == 'classification_trees' }

          return config[:hidden_filter].concat(selected_filters.select { |f| f['c'] == 'd' }) if classification_filter.blank?

          filterable_classification_aliases(classification_filter[:config], config[:excluded_types]).each do |tree_label, classification_aliases|
            value = selected_filters.find { |f| f['c'] == 'd' && f['n'] == tree_label }
            classification_filter[:filters] ||= {}
            classification_filter[:filters][tree_label] = {
              classification_aliases:,
              value: value&.dig('v'),
              identifier: value&.dig('identifier') || SecureRandom.hex(10)
            }
          end

          config[:hidden_filter].concat(selected_filters.select { |f| f['c'] == 'd' && classification_filter[:filters].keys.exclude?(f['n']) }) if classification_filter[:filters].present?
        end

        def search_filters(_user, config, selected_filters)
          search_filter = config[:filter].find { |v| v[:type] == 'search' }
          value = selected_filters.find { |f| f['t'] == 'fulltext_search' }

          if search_filter.blank?
            config[:hidden_filter].push(value) if value.present?
            return
          end

          search_filter[:value] = value&.dig('v')
          search_filter[:identifier] = value&.dig('identifier') || SecureRandom.hex(10)
        end

        def advanced_filters(user, config, selected_filters, key = :advanced, c = 'a', buttons = true)
          advanced_filter = config[:filter].find { |v| v[:type] == key.to_s }
          selected = selected_filters.select { |f| f['c'] == c && f['t'] != 'fulltext_search' }

          return config[:hidden_filter].concat(selected) if advanced_filter.blank?

          allowed_filters = allowed_advanced_filters(user, config[:view_type], selected, c)
          advanced_filter[:filters] = configs_intersection(selected, allowed_filters)
          config[:hidden_filter].concat(configs_difference(selected, allowed_filters))

          visible_filters = DataCycleCore::Feature::AdvancedFilter.available_visible_filters(user, config[:view_type], advanced_filter[:config])

          visible_filters.each do |_k, v, data|
            filter_hash = transform_advanced_filter(data, c, v)

            existing_index = advanced_filter[:filters].index { |f| configs_equal?(filter_hash, f) }

            advanced_filter[:filters].prepend(existing_index ? advanced_filter[:filters].delete_at(existing_index) : filter_hash)
          end

          advanced_filter[:filters].each do |filter|
            filter['buttons'] = buttons
          end
        end

        def advanced_user_filters(_user, config, selected_filters)
          advanced_filter = config[:filter].find { |v| v[:type] == 'advanced' }
          return if advanced_filter.blank?

          advanced_filter[:filters].concat(Array.wrap(selected_filters.select { |f| f['c'] == 'u' }))
          advanced_filter[:filters].select { |f| f['c'] == 'u' }.each do |filter|
            filter['buttons'] = true
          end
        end

        def classification_tree_filters(_user, config, selected_filters)
          tree_filter = config[:filter].find { |v| v[:type] == 'classification_tree' }

          return config[:hidden_filter].concat(selected_filters.select { |f| f['c'] == 's' }) if tree_filter.blank?

          tree_label = tree_filter[:config]
          value = selected_filters.find { |f| f['c'] == 's' && f['n'] == tree_label }
          tree_filter[:classification_aliases] = filterable_classification_aliases(tree_label, config[:excluded_types], false)&.dig(tree_label)
          tree_filter[:value] = value&.dig('v')
          tree_filter[:identifier] = value&.dig('identifier') || SecureRandom.hex(10)
        end

        def autoload_last_filter?
          configuration.dig('autoload_last_filter')
        end

        def filterable_classification_aliases(allowed_labels, excluded = [], include_tree = true)
          query = DataCycleCore::ClassificationAlias
            .preload(:primary_classification, :classification_alias_path)
            .includes(:classification_tree_label, :parent_classification_alias)
            .where(classification_tree_labels: { name: allowed_labels })
          query = query.where(classification_trees: { parent_classification_alias: nil }) unless include_tree
          query = query.where.not(classification_tree_labels: { name: 'Inhaltstypen' }).or(query.where.not(internal_name: excluded))

          # preload children and parents with includes
          ActiveRecord::Associations::Preloader.new.preload(query, :sub_classification_trees, DataCycleCore::ClassificationTree.select(:classification_alias_id, :parent_classification_alias_id, :deleted_at))
          ActiveRecord::Associations::Preloader.new.preload(query, :classification_tree, DataCycleCore::ClassificationTree.select(:classification_alias_id, :parent_classification_alias_id, :deleted_at))

          preloaded = query.index_by(&:id)

          query.each do |ca|
            # set preloaded sub_classification_alias
            records = preloaded.values_at(*ca.sub_classification_trees.pluck(:classification_alias_id)).compact.sort_by(&:order_a)
            association = ca.association(:sub_classification_alias)
            association.loaded!
            association.target.concat(records)
            records.each { |record| association.set_inverse_instance(record) }

            # set preloaded parent_classification_alias
            record = preloaded[ca.classification_tree.parent_classification_alias_id]
            association = ca.association(:parent_classification_alias)
            association.target = record
            association.set_inverse_instance(record) if record
          end

          query.filter { |ca| ca.parent_classification_alias.nil? }.group_by { |ca| ca.classification_tree_label&.name }.sort_by { |k, _v| allowed_labels.index(k) }.to_h
        end

        def available_user_advanced_filters(user, view)
          return {} unless enabled? && !user.nil?

          filters = []

          configuration.dig(:config, view, :filter).find { |f| f.key?('user_advanced') }&.values&.first&.each do |key, value|
            filters.concat(DataCycleCore::Feature::AdvancedFilter.try(key.to_sym, user, value) || DataCycleCore::Feature::AdvancedFilter.default(user, key.to_s, value) || [])
          end

          filters
            .sort
            .group_by { |f| f[1] }
            .transform_keys { |k| I18n.t("filter_groups.#{k}", default: k, locale: user.ui_locale) }
        end

        private

        def transform_advanced_filter(data, c = nil, t = nil)
          return if data.blank?

          {
            'c' => c,
            't' => t,
            'n' => data.dig(:data, :name),
            'q' => data.dig(:data, :advancedType),
            'identifier' => SecureRandom.hex(10)
          }
        end

        def configs_intersection(configs1, configs2)
          configs1.select { |config1| configs2.any? { |config2| configs_equal?(config1, config2) } }
        end

        def configs_difference(configs1, configs2)
          configs1.reject { |config1| configs2.any? { |config2| configs_equal?(config1, config2) } }
        end

        def configs_equal?(config1, config2)
          comparable_key = ['c', 't']
          comparable_key << 'q' if config1['t']&.in?(AdvancedFilter.all_filters_with_advanced_type)
          comparable_key << 'n' if AdvancedFilter.filter_requires_n_for_comparison?(config1)
          comparable_key.all? { |k| config1[k].presence == config2[k].presence }
        end

        def allowed_advanced_filters(user, view_type, selected, c = 'a')
          return [] if selected.blank?

          filter_proc = ->(_, v, data) { selected.any? { |f| configs_equal?(transform_advanced_filter(data, c, v), f) } }

          DataCycleCore::Feature::AdvancedFilter
            .all_available_filters(user, view_type, filter_proc)
            .map { |_k, v, data| transform_advanced_filter(data, c, v) }
        end
      end
    end
  end
end
