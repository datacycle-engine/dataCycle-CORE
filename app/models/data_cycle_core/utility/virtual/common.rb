# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Common
        class << self
          def copy_plain(virtual_parameters:, content:, language:, **_args)
            attribute_name = virtual_parameters.first
            single_value = !content.translatable_property_names.include?(attribute_name) || (language.size == 1 && content.available_locales.map(&:to_s).include?(language.first))

            if single_value
              data_value = content.try(virtual_parameters.first)
            else
              data_value = []

              content.translations.each do |translation|
                next unless language.include?(translation.locale)

                I18n.with_locale(translation.locale) do
                  data_value << { '@language' => I18n.locale, '@value' => content.send(virtual_parameters.first + '_overlay') } if content.send(virtual_parameters.first + '_overlay').present?
                end
              end
            end
            data_value
          end
<<<<<<< HEAD
=======

          def take_first(virtual_parameters:, content:, **_args)
            virtual_parameters.each do |virtual_key|
              val = content.try(virtual_key.to_sym)
              return val if val.present?
            end
            nil
          end
>>>>>>> old/develop
        end
      end
    end
  end
end
