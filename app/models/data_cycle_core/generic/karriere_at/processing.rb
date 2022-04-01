# frozen_string_literal: true

module DataCycleCore
  module Generic
    module KarriereAt
      module Processing
        def self.process_organization(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::KarriereAt::Transformations.job_to_organization,
            default: { template: 'Organization' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::KarriereAt::Transformations.job_to_place,
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end

        def self.process_job(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::KarriereAt::Transformations.job_to_jobposting(utility_object.external_source.id),
            default: { template: 'JobPosting' },
            config: config
          )
        end
      end
    end
  end
end
