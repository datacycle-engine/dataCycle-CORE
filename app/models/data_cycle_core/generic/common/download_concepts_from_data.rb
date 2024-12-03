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
          raise ArgumentError, 'missing read_type for download_concepts_from_data' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])

          concept_name = options.dig(:download, :concept_name_path)
          concept_id = options.dig(:download, :concept_id_path) || concept_name
          concept_parent_id = options.dig(:download, :concept_parent_id_path) || 'parent_id'
          priority = options.dig(:download, :priority) || 5
          concept_uri = options.dig(:download, :concept_uri_path) || 'uri'

          concept_path = options.dig(:download, :concept_path) || ''
          full_concept_path = ["dump.#{locale}", concept_path].compact_blank.join('.')
          concept_id_path = [concept_path, concept_id].compact_blank.join('.')
          # concept_name_path = [concept_path, concept_name].compact_blank.join('.')
          # concept_parent_id_path = [concept_path, concept_parent_id].compact_blank.join('.')
          # concept_uri_path = [concept_path, concept_uri].compact_blank.join('.')

          match_path = ['dump', locale, concept_id_path].compact_blank.join('.')
          source_filter_stage = { match_path => { '$ne' => nil } }.with_indifferent_access
          source_filter_stage.merge!(source_filter) if source_filter.present?

          post_unwind_source_filter_stage = source_filter_stage
            .deep_stringify_keys
            .deep_reject { |k, _| !k.start_with?('$') && k.exclude?(full_concept_path) }
            .deep_transform_keys { |k| k.gsub(full_concept_path, 'data') }

          project_filter_stage = {
            'data' => ['$dump', locale, concept_path].compact_blank.join('.')
          }

          final_projection_stage = {
            'data.id' => ['$data', concept_id].compact_blank.join('.'),
            'data.name' => ['$data', concept_name].compact_blank.join('.'),
            'data.parent_id' => ['$data', concept_parent_id].compact_blank.join('.'),
            'data.uri' => ['$data', concept_uri].compact_blank.join('.'),
            'data.priority' => priority
          }

          pipelines = [
            {
              '$match' => source_filter_stage
            },
            {
              '$project' => project_filter_stage
            },
            {
              '$unwind' => '$data'
            },
            {
              '$match' => post_unwind_source_filter_stage
            },
            {
              '$project' => final_projection_stage
            },
            {
              '$group' => {
                '_id' => '$data.id',
                'data' => { '$first' => '$data' }
              }
            },
            {
              '$replaceRoot' => { 'newRoot' => '$data' }
            }
          ]

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              pipelines
            ).to_a
          end
        end

        def self.data_id(external_id_hash_method, data)
          case external_id_hash_method
          when 'MD5'
            Digest::MD5.hexdigest(data['id'])
          else
            data['id']
          end
        end

        def self.data_name(data)
          data['name']
        end
      end
    end
  end
end
