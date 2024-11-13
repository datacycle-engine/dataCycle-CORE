# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module Content
        def title
          raise NotImplementedError
        end

        def desc
          raise NotImplementedError
        end

        def as_json(options = {})
          return super(methods: :is_valid?) if options.blank? == false && options['add_validity'] == true
          super
        end

        def asset_web_url
          return unless try(:asset)&.versions&.key?(:web)

          DataCycleCore::ActiveStorageService.with_current_options do
            asset&.web&.url
          end
        rescue StandardError
          nil
        end

        def validation_messages_as_json
          {
            valid: valid?,
            errors: errors.messages,
            warnings: warnings.messages
          }
        end

        def first_available_locale(locale = nil, ui_locale = nil)
          available_locales = I18n.available_locales.dup
          available_locales.prepend(I18n.locale)
          available_locales.prepend(ui_locale.to_sym) if ui_locale.present?
          available_locales.prepend(*Array.wrap(locale).map(&:to_sym).sort_by! { |t| available_locales.index t })

          available_locales.intersection(translated_locales).first
        end

        def is_valid?
          if try(:validity_period)
            valid_from, valid_to = get_validity_values(validity_period.to_h)
            return Time.zone.today.between?(valid_from.to_date, valid_to.to_date) if valid_from.blank? == false && valid_to.blank? == false
            return Time.zone.today <= valid_to.to_date if valid_to.blank? == false
            return Time.zone.today >= valid_from.to_date if valid_from.blank? == false
          end

          true
        end

        def to_select_option(locale = DataCycleCore.ui_locales.first)
          DataCycleCore::Filter::SelectOption.new(
            id,
            ActionController::Base.helpers.safe_join([
              ActionController::Base.helpers.tag.i(class: "fa dc-type-icon thing-icon #{template_name.underscore_blanks}"),
              I18n.with_locale(first_available_locale) { title },
              "(#{translated_locales.join(', ')})"
            ].compact, ' '),
            "#{template_name.underscore_blanks} #{schema_type.underscore_blanks}",
            "#{translated_template_name(locale)}: #{I18n.with_locale(first_available_locale) { title }} (#{translated_locales.join(', ')})"
          )
        end
      end
    end
  end
end
