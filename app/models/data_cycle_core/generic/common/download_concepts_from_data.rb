# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptsFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_concepts_from_mongo).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :external_id_hash_method)],
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_concepts_from_mongo(options:, locale:, source_filter:, **_keyword_args)
          raise ArgumentError, 'missing read_type for loading location ranges' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])

          concept_name = options.dig(:download, :concept_name_path)
          concept_id = options.dig(:download, :concept_id_path) || concept_name
          concept_parent_id = options.dig(:download, :concept_parent_id_path) || 'parent_id'
          priority = options.dig(:download, :priority) || 5

          concept_path = options.dig(:download, :concept_path) || ''
          concept_id_path = [concept_path, concept_id].compact_blank.join('.')
          concept_name_path = [concept_path, concept_name].compact_blank.join('.')
          concept_parent_id_path = [concept_path, concept_parent_id].compact_blank.join('.')
          match_path = ['dump', locale, concept_id_path].compact_blank.join('.')

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              [
                {
                  '$match' => { match_path => { '$exists' => true } }.merge(source_filter.deep_stringify_keys)
                },
                {
                  '$unwind' => ['$dump', locale, concept_path].compact_blank.join('.')
                }, {
                  '$project' => {
                    'data.id' => ['$dump', locale, concept_id_path].compact_blank.join('.'),
                    'data.name' => ['$dump', locale, concept_name_path].compact_blank.join('.'),
                    'data.parent_id' => ['$dump', locale, concept_parent_id_path].compact_blank.join('.'),
                    'data.priority' => priority
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

        def self.data_id(external_id_hash_method, data)
          case external_id_hash_method
          when 'MD5'
            Digest::MD5.hexdigest(data.dig('id'))
          else
            data.dig('id')
          end
        end

        def self.data_name(data)
          data.dig('name')
        end
      end
    end
  end
end
