module DataCycleCore
  module MasterData
    module Validators
      class String < BasicValidator
        @@string_keywords = ['minLength', 'maxLength', 'format', 'pattern']
        @@string_formats = ['date_time', 'date', 'uuid', 'boolean', 'url']

        def validate(data, template)
          if data.is_a?(::String)
            if template.key?("validations")
              template["validations"].keys.each do |key|
                if @@string_keywords.include?(key)
                  self.method(key).call(data, template["validations"][key])
                else
                  @error[:warning].push I18n.t :string, scope: [:validation, :warnings], data: data, key: key, template: template, locale: DataCycleCore.ui_language unless key == "type"
                end
              end
            end
          else
            if data.blank?
              @error[:warning].push I18n.t :no_data, scope: [:validation, :warnings], data: template["label"], locale: DataCycleCore.ui_language
            else
              @error[:error].push I18n.t :string, scope: [:validation, :errors], template: data.class, label: template["label"], locale: DataCycleCore.ui_language
            end
          end
          return @error
        end

        private

        # given string validations

        def minLength(data, value)
          @error[:error].push I18n.t :min, scope: [:validation, :errors], data: data, min: value.to_i, length: data.length, locale: DataCycleCore.ui_language if data.length < value.to_i
        end

        def maxLength(data, value)
          @error[:error].push I18n.t :max, scope: [:validation, :errors], data: data, max: value.to_i, length: data.length, locale: DataCycleCore.ui_language if data.length > value.to_i
        end

        def pattern(data, expression)
          regex = /#{expression[1..expression.length - 2]}/
          matched = data.match(regex)
          @error[:error].push I18n.t :match, scope: [:validation, :errors], data: data, expression: expression, locale: DataCycleCore.ui_language if matched.nil? || matched.offset(0) != [0, data.size]
        end

        def format(data, format_string)
          if @@string_formats.include?(format_string)
            self.method(format_string).call(data)
          else
            @error[:error].push I18n.t :format, scope: [:validation, :errors], data: data, format_string: format_string, locale: DataCycleCore.ui_language
          end
        end

        # check string for given format

        def uuid(data)
          data.downcase!
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data =~ uuid).nil?
          @error[:error].push I18n.t :uuid, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language unless check_uuid
        end

        def date_time(data)
          # byebug
          # test = data.to_datetime
          # test2 = data.to_datetime.to_s
          # if data == test2
          #   isvalid = true
          # else
          #   isvalid = false
          # end

          data.to_datetime
        rescue
          @error[:error].push I18n.t :date_time, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language
        end

        def date(data)
          data.to_date
        rescue
          @error[:error].push I18n.t :date, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language
        end

        def boolean(data)
          @error[:error].push I18n.t :boolean, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language unless data.squish == "true" || data.squish == "false"
        end

        def url(data)
          unless data.blank?
            begin
              uri = URI.parse data
              @error[:error].push I18n.t :url, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language unless uri.is_a? URI::HTTP
            rescue URI::InvalidURIError
              @error[:error].push I18n.t :url, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language
            end
          end
        end
      end
    end
  end
end
