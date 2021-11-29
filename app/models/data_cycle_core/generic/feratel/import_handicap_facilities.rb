# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportHandicapFacilities
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label) || 'Feratel - HandicapFacilities',
            method(:load_root_classifications).to_proc,
            method(:load_child_classifications).to_proc,
            method(:load_parent_classification_alias).to_proc,
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(_mongo_item, locale, _options)
          DataCycleCore::Classification
            .where("external_key ILIKE 'Feratel - HandicapFacilityGroup - %'")
            .map { |item|
              {
                'Id' => item.external_key.split(' - ').last,
                'GroupID' => nil,
                'root' => true,
                'Name' => { 'Translation' => { 'text' => item.primary_classification_alias.name } }
              }
            }.map { |data| { 'dump' => { locale.to_s => data } }.with_indifferent_access }
        end

        def self.load_child_classifications(mongo_item, parent_data, locale = 'de')
          return [] unless parent_data.dig('root')
          mongo_item.where("dump.#{locale}.GroupID": parent_data.dig('Id')) # , "dump.#{locale}.ValueType": 'YesNo'
        end

        def self.load_parent_classification_alias(raw_data, external_source_id, _options = {})
          return nil if raw_data.dig('GroupID').blank?
          DataCycleCore::Classification
            .find_by(
              external_source_id: external_source_id,
              external_key: 'Feratel - HandicapFacilityGroup - ' + raw_data.dig('GroupID')
            )
            .try(:primary_classification_alias)
        end

        def self.extract_data(_options, raw_data)
          prefix = raw_data.dig('GroupID').blank? ? 'Feratel - HandicapFacilityGroup - ' : 'Feratel - HandicapFacility - '
          {
            external_key: prefix + raw_data.dig('Id').to_s,
            name: raw_data.dig('Name', 'Translation', 'text')
          }
        end
      end
    end
  end
end
