# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportTimeOfDay
        def self.import_data(utility_object:, options:)
          options.dig(:locales).each do |locale|
            I18n.with_locale(locale) do
              next unless locale.to_s.in?(['de', 'en', 'fr'])
              day_list =
                case locale.to_s
                when 'de'
                  ['0 Uhr', '3 Uhr', 'Vormittag', '9 Uhr', 'Nachmittag', '15 Uhr', 'Abend', '21 Uhr']
                when 'en'
                  ['0 am', '3 am', 'Morning', '9 am', 'Afternoon', '3 pm', 'Eventing', '9 pm']
                when 'fr'
                  ['0 heures', '3 heures', 'Matin', '9 heures', 'Après-midi', '15 heures', 'Soir', '21 heures']
                end
              day_list.zip(['00', '03', '06', '09', '12', '15', '18', '21']).each do |name, idx|
                classification_data = {
                  name: name,
                  external_key: "Feratel Webcams - Tageszeit - #{idx}",
                  tree_name: 'Fertael Webcams - Tageszeiten'
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
