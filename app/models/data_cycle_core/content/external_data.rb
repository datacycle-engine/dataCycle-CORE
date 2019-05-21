# frozen_string_literal: true

module DataCycleCore
  module Content
    module ExternalData
      def add_external_system_data(external_system, data = nil, status = nil)
        external_data = thing_external_systems.find_or_initialize_by(external_system_id: external_system.id)
        external_data.update({ data: data, status: status }.compact)
      end

      def remove_external_system_data(external_system)
        external_data = thing_external_systems.find_by(external_system_id: external_system.id)
        external_data.update(data: nil)
      end

      def external_system_data(external_system)
        thing_external_systems.find_by(external_system_id: external_system.id)&.data
      end
    end
  end
end
