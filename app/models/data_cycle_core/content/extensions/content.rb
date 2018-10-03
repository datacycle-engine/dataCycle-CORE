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

        def first_available_locale(locale = nil)
          translated = [locale].flatten & translated_locales.map(&:to_s)
          if translated.present? then translated.first.try(:to_sym)
          elsif translated_locales.include?(I18n.locale) then I18n.locale
          else translated_locales.first
          end
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
      end
    end
  end
end
