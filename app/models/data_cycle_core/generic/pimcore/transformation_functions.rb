# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Pimcore
      module TransformationFunctions
        extend Transproc::Registry
        import Transproc::HashTransformations
        import Transproc::Conditional
        import Transproc::Recursion
        import DataCycleCore::Generic::Common::Functions

        def self.add_potential_action(data, external_source_id)
          url = validate_url(data.dig('localizedData', 'bookingLink').presence)

          return data if url.blank?

          external_key = "#{data.dig('external_key')} - #{url}"

          data['potential_action'] = [{
            'id' => DataCycleCore::Thing.find_by(external_source_id: external_source_id, external_key: external_key)&.id,
            'external_key' => external_key,
            'external_source_id' => external_source_id,
            'name' => 'potential_action',
            'url' => url,
            'action_type' => DataCycleCore::ClassificationAlias.classifications_for_tree_with_name('ActionTypes', 'View')
          }]

          data
        end

        def self.validate_url(url)
          schemes = ['http', 'https', 'mailto', 'ftp', 'sftp', 'tel']
          begin
            url if schemes.include?(Addressable::URI.parse(url)&.scheme)
          rescue Addressable::URI::InvalidURIError
            nil
          end
        end

        def self.add_info(data, fields, external_source_id)
          additional_information = fields.map { |type|
            next if data[type].blank?
            text = {}
            text['name'] = I18n.t("import.pimcore.#{type}", default: [type])
            text['type_of_info'] = type
            text['type'] = type
            text['description'] = data[type]
            text['external_key'] = "Pimcore - AdditionalInformation - #{data.dig('external_key')} - #{type}"
            text
          }.compact
          data['additional_information'] ||= []
          data['additional_information'] += DataCycleCore::Generic::Common::Transformations::AdditionalInformation.add_info(additional_information, external_source_id)
          data
        end
      end
    end
  end
end
