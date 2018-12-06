# frozen_string_literal: true

module DataCycleCore
  module Content
    module ExternalData
      def add_external_system_data(external_system, data)
        self.external_systems = [external_system]
        external_data = thing_external_systems.with_external_system(external_system.id)
        external_data.data = data
        external_data.save
        save(touch: false)
      end

      def remove_external_system_data(external_system)
        external_data = thing_external_systems.with_external_system(external_system.id)
        external_data.data = nil
        external_data.save
      end

      def external_system_data(external_system)
        thing_external_systems.with_external_system(external_system.id)&.try(&:data)
      end
    end
  end
end
