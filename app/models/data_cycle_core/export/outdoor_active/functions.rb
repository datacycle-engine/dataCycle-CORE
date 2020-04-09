# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module Functions
        def self.transformations
          DataCycleCore::Export::Common::Transformations
        end

        def self.update(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system)
          data.add_external_system_data(external_system, nil, 'pending')

          utility_object.logging.info("update -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)

          Delayed::Job.enqueue(
            DataCycleCore::Export::OutdoorActive::Webhook.new(
              data: OpenStruct.new(id: data.id, template_name: data.template_name),
              external_system: external_system,
              external_system_data: external_system_data,
              endpoint: utility_object.endpoint,
              request: :update_request
            )
          )
        end

        def self.update_job_status(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system)

          utility_object.logging.info("update_job_status -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)

          Delayed::Job.enqueue(
            DataCycleCore::Export::OutdoorActive::Webhook.new(
              data: OpenStruct.new(id: data.id, template_name: data.template_name),
              external_system: external_system,
              external_system_data: external_system_data,
              endpoint: utility_object.endpoint,
              request: :job_status_request
            )
          )
        end

        def self.delete(utility_object:, data:)
          external_system = utility_object.external_system
          external_system_data = data.external_system_data(external_system)
          data.add_external_system_data(external_system, nil, 'deleting')

          utility_object.logging.info("delete -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)

          Delayed::Job.enqueue(
            DataCycleCore::Export::OutdoorActive::Webhook.new(
              data: OpenStruct.new(id: data.id, template_name: data.template_name),
              external_system: external_system,
              external_system_data: external_system_data,
              endpoint: utility_object.endpoint,
              request: :update_request
            )
          )
        end

        def self.outdoor_active_system_categories(data, external_system)
          outdoor_active_categories(data, external_system, 'OutdoorActive - System - Kategorien')
        end

        def self.outdoor_active_system_source_keys(data, external_system)
          outdoor_active_categories(data, external_system, 'OutdoorActive - System - Quellen')
        end

        def self.outdoor_active_system_status(data, external_system)
          statuses = outdoor_active_categories(data, external_system, 'OutdoorActive - System - Stati')

          if statuses.blank? ||
             outdoor_active_system_categories(data, external_system).blank? ||
             outdoor_active_system_source_keys(data, external_system).blank?

            'offline'
          elsif statuses.size == 1
            statuses.first.primary_classification_alias.internal_name
          else
            raise 'Ambiguous value for "OutdoorActive - System - Status"'
          end
        end

        def self.outdoor_active_categories(data, external_system, tree_label)
          external_source_id = DataCycleCore::ExternalSource.find_by(name: external_system.credentials.dig('external_source'))&.id

          data.classifications.includes(:classification_aliases)
            .map(&:classification_aliases).flatten.uniq
            &.select do |c|
            c.external_source_id == external_source_id && c.classification_tree.classification_tree_label.name == tree_label
          end&.map(&:primary_classification)
        end
      end
    end
  end
end
