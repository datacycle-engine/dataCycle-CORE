# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module ImportCertificateType
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge({ iterator_type: :aggregate })
          )
        end

        def self.load_contents(mongo_item, locale, _source_filter)
          mongo_item.collection.aggregate(
            [
              {
                '$project': {
                  'key': "$dump.#{locale}.certificate_data.certificate_type.key",
                  'label': "$dump.#{locale}.certificate_data.certificate_type.label_#{locale}",
                  'url': "$dump.#{locale}.certificate_data.certificate_type.icon_url_#{locale}"
                }
              }, {
                '$group': {
                  _id: '$url',
                  'key': { '$first': '$key' },
                  'label': { '$first': '$label' },
                  'url': { '$first': '$url' }
                }
              }, {
                '$addFields': {
                  "dump.#{locale}.description": '$key',
                  "dump.#{locale}.name": '$label',
                  "dump.#{locale}.url": '$url'
                }
              }
            ]
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            DataCycleCore::Generic::ReisenFuerAlle::Processing.process_icon(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :icon)
            )
          end
        end
      end
    end
  end
end
