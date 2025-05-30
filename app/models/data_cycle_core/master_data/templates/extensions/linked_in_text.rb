# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module LinkedInText
          LINKED_BASE_PROP = {
            type: 'linked',
            label: 'Inhalte in Text verlinkt',
            local: true,
            visible: 'show',
            stored_filter: [
              {
                with_classification_paths: [
                  'SchemaTypes > CreativeWork',
                  'SchemaTypes > Organization',
                  'SchemaTypes > Person',
                  'SchemaTypes > Place',
                  'SchemaTypes > Event',
                  'SchemaTypes > Intangible'
                ]
              }
            ]
          }.freeze
          LINKED_IN_TEXT_PREFIX = 'linked_in_text_'
          LINKED_TO_TEXT_PREFIX = 'linked_to_text_'

          def add_linked_in_text_properties!(props)
            linked_in_text_keys = props.select { |_, v|
              v[:type] == 'string' &&
                v.dig(:ui, :edit, :type) == 'text_editor' &&
                v.dig(:ui, :edit, :options, :'data-size') == 'full'
            }.keys

            linked_in_text_keys.each do |k|
              key = LINKED_IN_TEXT_PREFIX + k
              inverse_key = LINKED_TO_TEXT_PREFIX + k
              props[key] = LINKED_BASE_PROP.merge({ inverse_of: inverse_key })
              @linked_to_text_keys << k unless @linked_to_text_keys.include?(k)
            end
          end

          def self.append_linked_to_text_props!(props, inverse_keys)
            inverse_keys.each do |key|
              props[LINKED_TO_TEXT_PREFIX + key] = LINKED_BASE_PROP.merge({
                inverse_of: LINKED_IN_TEXT_PREFIX + key
              })
            end
          end
        end
      end
    end
  end
end
