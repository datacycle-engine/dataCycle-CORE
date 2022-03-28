# frozen_string_literal: true

module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters(view:, user:, selected_filters:)
          config = configuration.dig(:config, view).deep_dup || {}
          config[:view_type] = view
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
          classification_trees_filters(user, config, selected_filters)
          search_filters(user, config, selected_filters)
          advanced_filters(user, config, selected_filters)
          advanced_filters(user, config, selected_filters, :permanent_advanced, 'p', false)
          classification_tree_filters(user, config, selected_filters)
        end

        def classification_trees_filters(_user, config, selected_filters)
          classification_filter = config[:filter].find { |v| v[:type] == 'classification_trees' }
          return if classification_filter.blank?

          filterable_classification_aliases(classification_filter[:config], config[:excluded_types]).each do |tree_label, classification_aliases|
            value = selected_filters.find { |f| f['c'] == 'd' && f['n'] == tree_label }
            classification_filter[:filters] ||= {}
            classification_filter[:filters][tree_label] = {
              classification_aliases: classification_aliases,
              value: value&.dig('v'),
              identifier: value&.dig('identifier') || SecureRandom.hex(10)
            }
          end
        end

        def search_filters(_user, config, selected_filters)
          search_filter = config[:filter].find { |v| v[:type] == 'search' }
          return if search_filter.blank?

          value = selected_filters.find { |f| f['t'] == 'fulltext_search' }

          search_filter[:value] = value&.dig('v')
          search_filter[:identifier] = value&.dig('identifier') || SecureRandom.hex(10)
        end

        def advanced_filters(user, config, selected_filters, key = :advanced, c = 'a', buttons = true)
          advanced_filter = config[:filter].find { |v| v[:type] == key.to_s }
          return if advanced_filter.blank?

          advanced_filter[:filters] = selected_filters.select { |f| f['c'] == c }
          visible_filters = DataCycleCore::Feature::AdvancedFilter.available_visible_filters(user, config[:view_type], advanced_filter[:config])

          visible_filters.each do |filter|
            filter_hash = {
              'c' => c,
              't' => filter[1],
              'n' => filter.dig(2, :data, :name),
              'q' => filter.dig(2, :data, :advancedType),
              'identifier' => SecureRandom.hex(10)
            }

            existing_index = advanced_filter[:filters].index { |f| filter_hash.except('identifier').reject { |_, v| v.blank? } == f.slice('c', 't', 'n', 'q').reject { |_, v| v.blank? } }

            advanced_filter[:filters].prepend(existing_index ? advanced_filter[:filters].delete_at(existing_index) : filter_hash)
          end

          advanced_filter[:filters].each do |filter|
            filter['buttons'] = buttons
          end
        end

        def classification_tree_filters(_user, config, selected_filters)
          tree_filter = config[:filter].find { |v| v[:type] == 'classification_tree' }
          return if tree_filter.blank?

          tree_label = tree_filter[:config]
          value = selected_filters.find { |f| f['c'] == 's' && f['n'] == tree_label }
          tree_filter[:classification_aliases] = filterable_classification_aliases(tree_label, config[:excluded_types])&.dig(tree_label)
          tree_filter[:value] = value&.dig('v')
          tree_filter[:identifier] = value&.dig('identifier') || SecureRandom.hex(10)
        end

        def autoload_last_filter?
          configuration.dig('autoload_last_filter')
        end

        def filterable_classification_aliases(allowed_labels, excluded = [])
          query = DataCycleCore::ClassificationAlias
            .includes(:classification_tree_label, :parent_classification_alias, :primary_classification, :classification_alias_path, :sub_classification_alias)
            .where(classification_tree_labels: { name: allowed_labels }, classification_trees: { parent_classification_alias: nil })
          query = query.where.not(classification_tree_labels: { name: 'Inhaltstypen' }).or(query.where.not(internal_name: excluded)).order(created_at: :asc)
          query.group_by { |ca| ca.classification_tree_label&.name }.sort_by { |k, _v| allowed_labels.index(k) }.to_h
        end
      end
    end
  end
end
