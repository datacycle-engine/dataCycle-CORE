# frozen_string_literal: true

module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters(view:, user:, selected_filters:)
          config = configuration.dig(:config, view).deep_dup || {}
          config[:view_type] = view
          config[:excluded_types] = DataCycleCore.excluded_filter_classifications
          config[:filter] ||= {}
          config[:filter].select! do |k, v|
            v.present? && user.can?(k.to_sym, view.to_sym, v)
          end
          config[:filter].transform_values! { |v| { config: v } }
          values_for_filters(user, config, config[:filter], Array.wrap(selected_filters))
          config[:sortable] = DataCycleCore::Feature::Sortable.available_options.select { |k, v| user.can?(:sortable, view.to_sym, k, v) } if config[:sortable].present?
          config
        end

        def values_for_filters(user, config, filters, selected_filters)
          classification_trees_filters(user, config, filters, selected_filters)
          search_filters(user, config, filters, selected_filters)
          advanced_filters(user, config, filters, selected_filters)
          classification_tree_filters(user, config, filters, selected_filters)
        end

        def classification_trees_filters(_user, config, filters, selected_filters)
          return if filters[:classification_trees].blank?

          filterable_classification_aliases(filters.dig(:classification_trees, :config), config[:excluded_types]).each do |tree_label, classification_aliases|
            value = selected_filters.find { |f| f['c'] == 'd' && f['n'] == tree_label }
            filters[:classification_trees][:filters] = {
              tree_label => {
                classification_aliases: classification_aliases,
                value: value&.dig('v'),
                identifier: value&.dig('identifier') || SecureRandom.hex(10)
              }
            }
          end
        end

        def search_filters(_user, _config, filters, selected_filters)
          return if filters[:search].blank?

          value = selected_filters.find { |f| f['t'] == 'fulltext_search' }

          filters[:search][:value] = value&.dig('v')
          filters[:search][:identifier] = value&.dig('identifier') || SecureRandom.hex(10)
        end

        def advanced_filters(user, config, filters, selected_filters)
          return if filters[:advanced].blank?

          filters[:advanced][:filters] = selected_filters.select { |f| f['c'] == 'a' }
          visible_filters = DataCycleCore::Feature::AdvancedFilter.available_visible_filters(user, config[:view_type], filters.dig(:advanced, :config))

          visible_filters.each do |filter|
            filter_hash = {
              'c' => 'a',
              't' => filter[1],
              'n' => filter.dig(2, :data, :name),
              'q' => filter.dig(2, :data, :advancedType),
              'm' => 'i',
              'identifier' => SecureRandom.hex(10)
            }

            filters[:advanced][:filters].prepend(filter_hash) unless filters[:advanced][:filters].any? { |f| filter_hash.except('identifier').all? { |k, v| f[k] == v } }
          end
        end

        def classification_tree_filters(_user, config, filters, selected_filters)
          return if filters[:classification_tree].blank?

          tree_label = filters.dig(:classification_tree, :config)
          value = selected_filters.find { |f| f['c'] == 's' && f['n'] == tree_label }
          filters[:classification_tree][:classification_aliases] = filterable_classification_aliases(tree_label, config[:excluded_types])&.dig(tree_label)
          filters[:classification_tree][:value] = value&.dig('v')
          filters[:classification_tree][:identifier] = value&.dig('identifier') || SecureRandom.hex(10)
        end

        def autoload_last_filter?
          configuration.dig('autoload_last_filter')
        end

        def filterable_classification_aliases(allowed_labels, excluded = [])
          query = DataCycleCore::ClassificationAlias
            .includes(:classification_tree_label, :parent_classification_alias, sub_classification_alias: [
                        sub_classification_alias: [
                          sub_classification_alias: :sub_classification_alias
                        ]
                      ])
            .where(classification_tree_labels: { name: allowed_labels }, classification_trees: { parent_classification_alias: nil })
          query = query.where.not(classification_tree_labels: { name: 'Inhaltstypen' }).or(query.where.not(internal_name: excluded))

          query.group_by { |ca| ca.classification_tree_label&.name }
        end
      end
    end
  end
end
