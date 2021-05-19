# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DataCycleTypo3
      module Processing
        def self.process_webpage(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DataCycleTypo3::Transformations.to_webpage,
            default: { template: 'Webpage' },
            config: config
          )
        end

        def self.process_website(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::DataCycleTypo3::Transformations.to_website,
            default: { template: 'Website' },
            config: config
          )
        end
      end
    end
  end
end
