# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Base
      class << self
        def execute(warning_methods, content, context = nil)
          warnings = []
          warning_methods.presence&.each do |w_method, w_params|
            next if try(w_method, w_params, content, context)

            warnings.push(I18n.t("#{name.underscore.tr('/', '.')}.#{w_method}", default: w_method, locale: DataCycleCore.ui_language))
          end
          warnings
        end

        def warnings(content, context = nil)
          warnings = []
          DataCycleCore.content_warnings.slice('Common', content.template_name).presence&.each do |key, value|
            warnings.concat("DataCycleCore::Warning::#{value.dig('class')&.classify || key.classify}".constantize.execute(value.except('class'), content, context))
          end
          warnings
        end
      end
    end
  end
end
