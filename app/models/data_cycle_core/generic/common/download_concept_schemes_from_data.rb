# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptSchemesFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_concept_schemes_from_data(
            download_object: utility_object,
            iterator: method(:load_concept_schemes_from_mongo).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:
          )
        end

        def self.load_concept_schemes_from_mongo(options:, lang:)
          raise ArgumentError, 'missing read_type for loading location ranges' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate([
                                         {
                                           '$match' => { "dump.#{lang}.tree_label" => { '$exists' => true } }
                                         }, {
                                           '$project' => {
                                             'id' => "$dump.#{lang}.tree_label",
                                             'name' => "$dump.#{lang}.tree_label"
                                           }
                                         }, {
                                           '$group' => {
                                             '_id' => '$id',
                                             'id' => { '$first' => '$id' },
                                             'name' => { '$first' => '$name' }
                                           }
                                         }
                                       ]).to_a
          end
        end

        def self.data_id(data)
          data.dig('id')
        end

        def self.data_name(data)
          data.dig('name')
        end
      end
    end
  end
end
