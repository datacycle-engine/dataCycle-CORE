# frozen_string_literal: true

module DataCycleCore
  module Feature
    class MainFilter < Base
      class << self
        def available_filters(view:, user:, selected_filters:, advanced_filters:)
          config = configuration.dig(:config, view).deep_dup || {}
          config[:view_type] = view
          config[:excluded_types] = DataCycleCore.excluded_filter_classifications
          config[:filter]&.filter! do |k, v|
            v.present? && user.can?(k.to_sym, view.to_sym, v)
          end
          config[:index] = config.dig(:filter, :classification_trees)&.size || 0
          config[:filter][:classification_trees] = filterable_classification_aliases(config.dig(:filter, :classification_trees), config[:excluded_types]) if config.dig(:filter, :classification_trees).present?
          config[:filter][:search] = selected_filters.presence&.find { |f| f['t'] == 'fulltext_search' }&.dig('v') if config.dig(:filter, :search).present?
          config[:filter][:advanced] = advanced_filters if config.dig(:filter, :advanced).present?
          config[:filter][:classification_tree] = filterable_classification_aliases(config.dig(:filter, :classification_tree), config[:excluded_types]) if config.dig(:filter, :classification_tree).present?
          config[:sortable] = DataCycleCore::Feature::Sortable.available_options.select { |k, v| user.can?(:sortable, view.to_sym, k, v) } if config[:sortable].present?
          config
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
