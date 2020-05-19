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

        def self.unwrap_content_description(data, description_types)
          raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

          description_types = Array(description_types)

          return data.map { |v| unwrap_content_description(v, description_types) } if data.is_a?(Array)

          description_types.map { |description_type|
            description_data = Array.wrap(data.dig('ContentDescriptions', 'ContentDescription'))
              .detect { |h| h['Type'] == description_type }
            description_text = description_data.try(:[], 'IntroText') || ''

            if description_data&.dig('Items', 'Item').present?
              item_data = description_data.dig('Items', 'Item').is_a?(::Array) ? description_data.dig('Items', 'Item') : [{ 'text' => description_data.dig('Items', 'Item') }]
              description_item = item_data.map { |item| item.try(:[], 'text') }.compact.join('</li> <li>')
              description_text += ' <ul> <li>' + description_item + '</li> </ul>' if description_item.present?
            end

            { description_type => description_text.presence }
          }.reduce(data.reject { |k, _| k == 'ContentDescriptions' }, &:merge)
        end

        def self.add_cc(data, external_source_id)
          if data.dig('CCId').present?
            classification = DataCycleCore::Classification.where(external_source_id: external_source_id, external_key: data.dig('CCId'))
            data = data.merge(feratel_creative_commons: classification&.ids)
          end
          data = data.merge(attribution_name: data.dig('CCAuthor')) if data.dig('CCAuthor').present?
          data = data.merge(license: data.dig('CCCopyright')) if data.dig('CCCopyright').present?
          data
        end

        def self.add_amenity_features(data, _external_source_id)
          amenity_features = []
          data.dig('Facilities', 'Facility').each do |facility|
            next unless facility['ValueType'] == 'IntDigit'
            amenity_features.push(
              {
                name: facility['GroupName'] + ' |> ' + facility['Name'],
                value: facility['Value'].to_i
              }
            )
          end
          data.merge({ 'amenity_feature' => amenity_features })
        end

        def self.add_service_description(data, attribute_name, description_name)
          raise ArgumentError unless data.is_a?(Hash)

          description = Array.wrap(data.dig('Descriptions', 'Description'))
            .detect { |item| item['Name'] == description_name && item['Type'] == 'AdditionalService' }
            &.dig('text')

          return data if description.blank?
          data.merge({ attribute_name => description })
        end

        def self.ensure_classification_tree(data, attribute_name, classification_tree)
          data.merge({
            attribute_name => DataCycleCore::Classification.for_tree(classification_tree)
                                                           .where(id: data[attribute_name])
                                                           .pluck(:id)
          })
        end

        def self.unwrap_address(data, address_type)
          raise ArgumentError unless data.is_a?(Array) || data.is_a?(Hash)

          Hash[data.map do |k, v|
            if k == 'Addresses'
              [
                'Address',
                [v['Address']].flatten.detect do |h|
                  h['Type'] == address_type
                end
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
