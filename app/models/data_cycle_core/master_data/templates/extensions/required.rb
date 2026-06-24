# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module Required
          EXTERNAL_KEY_BASE = {
            'type' => 'string',
            'storage_location' => 'column',
            'visible' => false
          }.freeze
          DUMMY_BASE = {
            'type' => 'string',
            'storage_location' => 'translated_value',
            'default_value' => 'do_not_show',
            'visible' => false
          }.freeze

          def add_required_properties!
            @templates.each do |template|
              next if template.dig(:data, :properties).blank?

              add_external_key_property!(template[:data][:properties])
              add_dummy_property!(template[:data][:properties])
            end
          end

          private

          def add_external_key_property!(properties)
            return if properties.key?(:external_key)

            properties[:external_key] = EXTERNAL_KEY_BASE
          end

          def add_dummy_property!(properties)
            return if properties.key?(:dummy)

            properties[:dummy] = DUMMY_BASE
          end
        end
      end
    end
  end
end
