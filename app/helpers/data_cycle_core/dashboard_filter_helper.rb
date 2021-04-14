# frozen_string_literal: true

module DataCycleCore
  module DashboardFilterHelper
    def union_ids_to_value(value)
      return if value.blank?

      filter_proc = ->(query, query_table) { query.where(query_table[:id].in(value)) }
      query = DataCycleCore::StoredFilter.combine_with_collections(DataCycleCore::WatchList.all, filter_proc)

      result = ActiveRecord::Base.connection.select_all query.to_sql

      result.to_a
    end

    def union_values_to_options(value)
      return if value.blank?

      options_for_select(
        union_ids_to_value(value)&.map do |s|
          [
            s['name'],
            s['id'],
            {
              title: "#{I18n.t("activerecord.models.data_cycle_core/#{s['class_name']}", count: 1, locale: DataCycleCore.ui_language)}: #{s['name']}",
              class: s['class_name']
            }
          ]
        end,
        value
      )
    end

    def advanced_attribute_filter_options(filter_advanced_type)
      case filter_advanced_type
      when 'string'
        [
          [t('common.like', locale: DataCycleCore.ui_language), 's'],
          [t('common.not_like', locale: DataCycleCore.ui_language), 'u'],
          [t('common.blank', locale: DataCycleCore.ui_language), 'b'],
          [t('common.present', locale: DataCycleCore.ui_language), 'p']
        ]
      when 'classification_alias_ids'
        [
          [t('common.has', locale: DataCycleCore.ui_language), 'i'],
          [t('common.has_not', locale: DataCycleCore.ui_language), 'e']
        ]
      when 'boolean'
        nil
      else
        [
          [t('common.is', locale: DataCycleCore.ui_language), 'i'],
          [t('common.is_not', locale: DataCycleCore.ui_language), 'e']
        ]
      end
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

    def local_filter_options(filter, filters)
      filter ||= {}

      filter[:excluded_types] = DataCycleCore.excluded_filter_classifications
      filter[:classification_trees] ||= DataCycleCore::Feature::MainFilter.available_filters
      filter[:index] = filter[:classification_trees].size
      filter[:classification_tree_data] = filterable_classification_aliases(filter[:classification_trees], filter[:excluded_types])
      filter[:fulltext_search] = filter[:search] && filters.presence&.find { |f| f['t'] == 'fulltext_search' }&.dig('v')

      filter
    end
  end
end
