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
          external_system_data = data.external_system_data(external_system, 'export', nil, false)
          data.add_external_system_data(external_system, nil, 'pending', 'export', nil, false)
          log("update -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)

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
          external_system_data = data.external_system_data(external_system, 'export', nil, false)
          log("update_job_status -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)

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
          external_system_data = data.external_system_data(external_system, 'export', nil, false)
          data.add_external_system_data(external_system, nil, 'deleting', 'export', nil, false)
          log("delete -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)
          # utility_object.logging.info("delete -> Export | OutdoorActive | #{utility_object.external_system.id}", data&.id)

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

        def self.filter(data:, external_system:, method_name:)
          source_key = external_system.credentials('export')&.dig('xml', 'owner') # == in this context the owner
          sync_data = data.external_system_data_all(external_system, 'export', nil, false)
          job_id = sync_data&.data&.dig('job_id')
          updated_at = sync_data&.updated_at || Time::LONG_AGO
          (
            DataCycleCore::Export::Generic::Functions.filter(data: data, external_system: external_system, method_name: method_name) &&
            (Functions.outdoor_active_system_source_keys(data, external_system).size.positive? || source_key.present?) &&
            (job_id.blank? || updated_at + 2.days < Time.zone.now)
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
          statuses = data.try(:outdoor_active_system_status) if data.try(:outdoor_active_system_status).present?

          if statuses.blank? ||
             outdoor_active_system_categories(data, external_system).blank? ||
             (outdoor_active_system_source_keys(data, external_system).blank? && external_system.credentials('export').dig('xml', 'owner').blank?)

            'offline'
          elsif statuses.size == 1
            statuses.first.primary_classification_alias.internal_name
          else
            raise 'Ambiguous value for "OutdoorActive - System - Status"'
          end
        end

        def self.outdoor_active_categories(data, external_system, tree_label)
          if tree_label == 'OutdoorActive - System - Kategorien' && (classifications = data.try(:outdoor_active_system_categories)).present?
            # used by Spielberg (for POI)
            classifications
          else
            # used by KW (Unterknunft)
            external_source_id = external_system&.id
            data.classifications.includes(:classification_aliases)
              .map(&:classification_aliases).flatten.uniq
              &.select { |c|
              c.external_source_id == external_source_id && c.classification_tree.classification_tree_label.name == tree_label
            }&.map(&:primary_classification)
          end
        end

        def self.log(message, id)
          init_logging do |logger|
            logger.info(message, id)
          end
        end

        def self.init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:export)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
