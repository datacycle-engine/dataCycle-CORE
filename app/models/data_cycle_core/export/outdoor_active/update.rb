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

        def self.filter(data, external_system)
          job_id = data.external_system_data(external_system)&.dig('job_id')
          (
            (data.template_name == 'POI' || data.template_name == 'Unterkunft')&&
            data&.external_source&.name == 'Feratel Kärnten' &&
            Functions.outdoor_active_system_categories(data, external_system).size.positive? &&
            Functions.outdoor_active_system_source_keys(data, external_system).size.positive? &&
            job_id.blank?
          )
        end
      end
    end
  end
end
