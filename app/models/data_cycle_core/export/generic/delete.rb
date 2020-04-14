# frozen_string_literal: true

module DataCycleCore
  module Export
    module Generic
      module Delete
        include Functions

        def self.process(utility_object:, data:)
          return if data.blank?

          Functions.delete(utility_object: utility_object, data: data)
        end

        def self.filter(data, external_system)
          data.template_name.in?(Array.wrap(external_system.config.dig('push_config', name.demodulize.underscore, 'template_names') || external_system.config.dig('push_config', 'template_names')))
        end
      end
    end
  end
end
