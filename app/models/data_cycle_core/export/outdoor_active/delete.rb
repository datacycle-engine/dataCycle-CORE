# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Delete
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?
          Functions.delete(utility_object: utility_object, data: data)
        end

        def self.filter(data, external_system)
          sync_data = data.external_system_data_all(external_system)
          job_id = sync_data.data&.dig('job_id')
          updated_at = sync_data.updated_at
          (
            (data.template_name == 'POI' || data.template_name == 'Unterkunft') &&
            data&.external_source&.identifier == 'feratel' &&
            Functions.outdoor_active_system_categories(data, external_system).size.positive? &&
            Functions.outdoor_active_system_source_keys(data, external_system).size.positive? &&
            (job_id.blank? || updated_at + 2.weeks < Time.zone.now)
          )
        end
      end
    end
  end
end
