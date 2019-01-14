# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Validators
      class String < BasicValidator
        def string_keywords
          ['min', 'max', 'format', 'pattern', 'required']
        end

        def string_formats
          ['uuid', 'url', 'email']
        end

        def validate(data, template)
          if data.blank? || data.is_a?(::String)
            if template.key?('validations')
              template['validations'].each_key do |key|
                if string_keywords.include?(key)
                  method(key).call(data, template['validations'][key])
                else
                  (@error[:warning][@template_key] ||= []) << I18n.t(:string, scope: [:validation, :warnings], data: data, key: key, template: template, locale: DataCycleCore.ui_language) unless key == 'type'
                end
              end
            end
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:string, scope: [:validation, :errors], template: data.class, label: template['label'], locale: DataCycleCore.ui_language)
          end
          @error
        end

        private

        # given string validations

        def min(data, value)
          text_length = ActionView::Base.full_sanitizer.sanitize(data).presence&.length.to_i
          (@error[:error][@template_key] ||= []) << I18n.t(:min, scope: [:validation, :errors], data: nil, min: value.to_i, length: text_length, locale: DataCycleCore.ui_language) if text_length < value.to_i
        end

        def max(data, value)
          text_length = ActionView::Base.full_sanitizer.sanitize(data).presence&.length.to_i
          (@error[:error][@template_key] ||= []) << I18n.t(:max, scope: [:validation, :errors], data: nil, max: value.to_i, length: text_length, locale: DataCycleCore.ui_language) if text_length.to_i > value.to_i
        end

        def pattern(data, expression)
          regex = /#{expression[1..expression.length - 2]}/
          matched = data.match(regex)
          (@error[:error][@template_key] ||= []) << I18n.t(:match, scope: [:validation, :errors], data: data, expression: expression, locale: DataCycleCore.ui_language) if matched.nil? || matched.offset(0) != [0, data.size]
        end

        def format(data, format_string)
          if string_formats.include?(format_string)
            method(format_string).call(data)
          else
            (@error[:error][@template_key] ||= []) << I18n.t(:format, scope: [:validation, :errors], data: data, format_string: format_string, locale: DataCycleCore.ui_language)
          end
        end

        def url(data)
          return if data.blank?
          begin
            uri = URI.parse data
            (@error[:error][@template_key] ||= []) << I18n.t(:url, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) unless uri.is_a? URI::HTTP
          rescue URI::InvalidURIError
            (@error[:error][@template_key] ||= []) << I18n.t(:url, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
          end
        end

        def required(data, value)
          (@error[:error][@template_key] ||= []) << I18n.t(:required, scope: [:validation, :errors], locale: DataCycleCore.ui_language) if value && data.blank?
        end

        # def email(data)
        #   unless data.blank?
        #     begin
        #       uri = URI.parse data
        #       URI::MailTo
        #       (@error[:error][@template_key] ||= []) << I18n.t(:url, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) unless uri.is_a? URI::HTTP
        #     rescue URI::InvalidURIError
        #       (@error[:error][@template_key] ||= []) << I18n.t(:url, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language)
        #     end
        #   end
        # end

        def uuid(data)
          data_uuid = data.downcase
          uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
          check_uuid = data.length == 36 && !(data_uuid =~ uuid).nil?
          (@error[:error][@template_key] ||= []) << I18n.t(:uuid, scope: [:validation, :errors], data: data, locale: DataCycleCore.ui_language) unless check_uuid
        end
      end
    end
  end
end
