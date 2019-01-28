# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.flatten_translations(data)
          raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

          return data.map { |v| flatten_translations(v) } if data.is_a?(Array)

          Hash[data.map do |k, v|
            if k == 'Translation'
              ['text', v['text']]
            elsif v.is_a?(Hash) || v.is_a?(Array)
              [k, flatten_translations(v)]
            else
              [k, v]
            end
          end]
        end

        def self.flatten_texts(data)
          raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

          return data.map { |v| flatten_texts(v) } if data.is_a?(Array)

          Hash[data.map do |k, v|
            if v.is_a?(Hash) && v.keys == ['text']
              [k, v['text']]
            elsif v.is_a?(Hash) || v.is_a?(Array)
              [k, flatten_texts(v)]
            else
              [k, v]
            end
          end]
        end

        def self.unwrap_description(data, description_types)
          raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

          description_types = Array(description_types)

          return data.map { |v| unwrap_description(v, description_types) } if data.is_a?(Array)

          description_types.map { |description_type|
            description_text = Array.wrap(data.dig('Descriptions', 'Description')).detect { |h|
              h['Type'] == description_type
            }.try(:[], 'text')

            { description_type => description_text }
          }.reduce(data.reject { |k, _| k == 'Descriptions' }, &:merge)
        end

        def self.unwrap_address(data, address_type)
          raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

          Hash[data.map do |k, v|
            if k == 'Addresses'
              [
                'Address',
                [v['Address']].flatten.detect { |h|
                  h['Type'] == address_type
                }
              ]
            elsif v.is_a?(Array)
              [k, v.map do |item|
                if item.is_a?(Array) || item.is_a?(Hash)
                  unwrap_address(item, address_type)
                else
                  item
                end
              end]
            elsif v.is_a?(Hash)
              [k, unwrap_address(v, address_type)]
            else
              [k, v]
            end
          end]
        end
      end
    end
  end
end
