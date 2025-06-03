# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        module LinkedInText
          LINKED_BASE_PROP = {
            type: 'linked',
            local: true,
            visible: ['api'],
            api: { name: 'dc:linkedInText' },
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
          LINKED_IN_TEXT_KEY = 'linked_in_text'
          LINKED_TO_TEXT_KEY = 'linked_to_text'

          def linked_in_text_prop(parameters)
            LINKED_BASE_PROP.merge({
              label: 'in Text verlinkte Inhalte',
              inverse_of: LINKED_TO_TEXT_KEY,
              api: { name: 'dc:linkedInText' },
              compute: {
                module: 'Linked',
                method: 'linked_from_text',
                parameters:
              }
            })
          end

          def self.linked_to_text_prop
            LINKED_BASE_PROP.merge({
              label: 'zu Text verlinkte Inhalte',
              inverse_of: LINKED_IN_TEXT_KEY,
              link_direction: 'inverse',
              api: { name: 'dc:linkedToText' }
            })
          end

          def add_linked_in_text_properties!(props)
            linked_in_text_keys = props.select { |_, v|
              v[:type] == 'string' &&
                v.dig(:ui, :edit, :type) == 'text_editor' &&
                v.dig(:ui, :edit, :options, :'data-size') == 'full'
            }.keys

            return if linked_in_text_keys.empty?

            props[LINKED_IN_TEXT_KEY] = linked_in_text_prop(linked_in_text_keys)
          end

          def self.append_linked_to_text_props!(props)
            props[LINKED_TO_TEXT_KEY] = linked_to_text_prop
          end
        end
      end
    end
  end
end
