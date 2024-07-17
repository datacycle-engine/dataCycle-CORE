# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptsFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_concepts_from_data(
            download_object: utility_object,
            iterator: method(:load_concepts_from_mongo).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:
          )
        end

        def self.load_concepts_from_mongo(options:, lang:, source_filter:)
          raise ArgumentError, 'missing read_type for loading location ranges' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])

          concept_name = options.dig(:download, :concept_name_path)
          concept_id = options.dig(:download, :concept_id_path) || concept_name

          concept_path = options.dig(:download, :concept_path) || ''
          concept_id_path = [concept_path, concept_id].compact_blank.join('.')
          concept_name_path = [concept_path, concept_name].compact_blank.join('.')

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate([
                                         {
                                           '$match' => { "dump.#{lang}" => { '$exists' => true } }.merge(source_filter.deep_stringify_keys)
                                         },
                                         {
                                           '$unwind' => ['$dump', lang, concept_path].compact_blank.join('.')
                                         }, {
                                           '$project' => {
                                             'id' => ['$dump', lang, concept_id_path].compact_blank.join('.'),
                                             'name' => ['$dump', lang, concept_name_path].compact_blank.join('.')
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
