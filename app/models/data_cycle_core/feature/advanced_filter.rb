module DataCycleCore
  module Feature
    class AdvancedFilter < Base
      class << self
        def available_filters
          filters = []
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym)&.except(:enabled)&.each do |key, value|
            filters.concat(try(key.to_sym, value) || [])
          end
          filters
        end

        def classification_alias_ids(value)
          if value == 'all'
            DataCycleCore::ClassificationTreeLabel.all.pluck(:name).map do |c|
              [
                I18n.t("filter.#{c}", default: c, locale: DataCycleCore.ui_language),
                'classification_alias_ids',
                data: { name: c }
              ]
            end
          elsif value.is_a?(Array)
            value.map do |c|
              [
                I18n.t("filter.#{c}", default: c, locale: DataCycleCore.ui_language),
                'classification_alias_ids',
                data: { name: c }
              ]
            end
          else
            []
          end
        end

        def external_source(value)
          if value
            [
              [
                I18n.t('filter.Externe_Quellen', default: 'Externe Quellen', locale: DataCycleCore.ui_language),
                'external_source',
                data: { name: 'Externe Quellen' }
              ]
            ]
          else
            []
          end
        end
      end
    end
  end
end