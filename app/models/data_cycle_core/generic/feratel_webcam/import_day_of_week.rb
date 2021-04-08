# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportDayOfWeek
        def self.import_data(utility_object:, options:)
          options.dig(:locales).each do |locale|
            I18n.with_locale(locale) do
              next unless locale.to_s.in?(['de', 'en', 'fr'])
              day_list =
                case locale.to_s
                when 'de'
                  ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag']
                when 'en'
                  ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
                when 'fr'
                  ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche']
                end
              day_list.each_with_index do |day, index|
                classification_data = {
                  name: day,
                  external_key: "Feratel Webcams - Wochentag - #{index}",
                  tree_name: 'Fertael Webcams - Wochentage'
                }
                DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                  utility_object: utility_object,
                  classification_data: classification_data,
                  parent_classification_alias: nil
                )
              end
            end
          end
        end
      end
    end
  end
end
