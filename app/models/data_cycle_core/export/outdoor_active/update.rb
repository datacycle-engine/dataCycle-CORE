# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Update
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.update(utility_object: utility_object, data: data)
        end

        def self.filter(data)
          external_system = DataCycleCore::ExternalSystem.find_by(name: 'OutdoorActive')
          job_id = data.external_system_data(external_system)&.dig('job_id')
          (
            data.template_name == 'POI' &&
            data.external_source.name == 'Feratel Kärnten' &&
            Functions.outdoor_active_categories(data).size.positive? &&
            job_id.blank?
          )
        end
      end
    end
  end
end
