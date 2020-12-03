# frozen_string_literal: true

module DataCycleCore
  module DashboardFilterHelper
    def union_ids_to_value(value)
      return if value.blank?

      filter_proc = ->(query, query_table) { query.where(query_table[:id].in(value)) }
      query = DataCycleCore::StoredFilter.combine_with_collections(DataCycleCore::WatchList.all, filter_proc)

      result = ActiveRecord::Base.connection.select_all query.to_sql

      options_for_select(
        result.map do |s|
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
  end
end
