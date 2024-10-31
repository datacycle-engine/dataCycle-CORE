# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptSchemesFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_concept_schemes_from_mongo).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_concept_schemes_from_mongo(options:, locale:, **_keyword_args)
          raise ArgumentError, 'missing read_type for loading location ranges' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              [
                {
                  '$match' => { "dump.#{locale}.tree_label" => { '$exists' => true } }
                }, {
                  '$project' => {
                    'data.id' => "$dump.#{locale}.tree_label",
                    'data.name' => "$dump.#{locale}.tree_label"
                  }
                }, {
                  '$group' => {
                    '_id' => '$data.id',
                    'data' => { '$first' => '$data' }
                  }
                }, {
                  '$replaceRoot' => { 'newRoot' => '$data' }
                }
              ]
            ).to_a
          end
        end

        def self.data_id(data)
          data['id']
        end

        def self.data_name(data)
          data['name']
        end
      end
    end
  end
end
