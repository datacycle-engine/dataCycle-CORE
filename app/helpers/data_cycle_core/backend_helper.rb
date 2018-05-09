module DataCycleCore
  module BackendHelper
    def get_user_for_id(id)
      DataCycleCore::User.find(id)
    end

    def parse_advanced_filters
      advanced_filters = []
      if DataCycleCore.available_filters[:advanced].is_a?(Hash) && DataCycleCore.available_filters.dig(:advanced, :classification_alias_ids) == 'all'
        advanced_filters = DataCycleCore::ClassificationTreeLabel.all.pluck(:name).map do |c|
          [
            t("filter.#{c}", default: c, locale: DataCycleCore.ui_language),
            'classification_alias_ids',
            data: { name: c }
          ]
        end
      elsif DataCycleCore.available_filters[:advanced].is_a?(Hash) && DataCycleCore.available_filters.dig(:advanced, :classification_alias_ids)&.is_a?(Array)
        advanced_filters = DataCycleCore.available_filters.dig(:advanced, :classification_alias_ids).presence&.map do |c|
          [
            t("filter.#{c}", default: c, locale: DataCycleCore.ui_language),
            'classification_alias_ids',
            data: { name: c }
          ]
        end
      end

      if DataCycleCore.available_filters[:advanced].is_a?(Hash) && DataCycleCore.available_filters[:advanced].except(:classification_alias_ids).present?
        advanced_filters.concat(DataCycleCore.available_filters[:advanced].except(:classification_alias_ids).map { |k, v|
          [
            t("filter.#{v}", default: v, locale: DataCycleCore.ui_language),
            k.to_s,
            data: { name: v }
          ]
        })
      end
      advanced_filters
    end
  end
end
