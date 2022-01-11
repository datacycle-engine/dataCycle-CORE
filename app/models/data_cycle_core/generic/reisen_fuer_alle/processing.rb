# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module Processing
        def self.process_rating(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::ReisenFuerAlle::Transformations.to_rating(utility_object.external_source.id, I18n.locale.to_s),
            default: { template: 'Zertifizierung' },
            config: config
          )
        end

        def self.process_icon(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::ReisenFuerAlle::Transformations.to_icon,
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
