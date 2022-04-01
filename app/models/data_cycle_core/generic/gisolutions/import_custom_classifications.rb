# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gisolutions
      module ImportCustomClassifications
        def self.import_data(utility_object:, options:)
          options.dig(:locales).each do |locale|
            I18n.with_locale(locale) do
              next unless locale.to_s.in?(['de'])
              custom_classifications = { 'artif_snow' => 'Beschneiungsanlage', 'floodlight' => 'Flutlicht' }
              custom_classifications.each do |key, value|
                classification_data = {
                  name: value,
                  external_key: "Gisolutions - Pistenausstattung - #{key}",
                  tree_name: 'Gisolutions - Pistenausstattungen'
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
