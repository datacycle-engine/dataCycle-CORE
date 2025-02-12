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
          # either both concept_name_path and concept_id_path should be present or none, hence the fallbacks
          concept_name = path_config(:name, options)&.then { |v| ERB.new(v).result(binding) }
          concept_id = path_config(:id, options) || concept_name
          concept_name ||= concept_id

          concept_parent_id = path_config(:parent_id, options) || 'parent_id'
          priority = options.dig(:download, :priority) || 5
          concept_uri = path_config(:uri, options) || 'uri'

          concept_path = path_config(nil, options) || ''
          concept_path += '[]' unless concept_path.end_with?('[]')
          array_positions = concept_path.split('.').map { |x| x.include?('[]') ? 1 : 0 }
          concept_path = concept_path.gsub('[]', '')

          # full_concept_path = ["dump.#{locale}", concept_path].compact_blank.join('.')
          concept_id_path = [concept_path, concept_id].compact_blank.join('.')
          # concept_name_path = [concept_path, concept_name].compact_blank.join('.')
          # concept_parent_id_path = [concept_path, concept_parent_id].compact_blank.join('.')
          # concept_uri_path = [concept_path, concept_uri].compact_blank.join('.')

          match_path = ['dump', locale, concept_id_path].compact_blank.join('.')
          source_filter_stage = { match_path => { '$exists' => true } }.with_indifferent_access
          source_filter_stage.merge!(source_filter) if source_filter.present?

          create_post_unwind_source_filter_stage = lambda do |c_path|
            source_filter_stage
              .deep_stringify_keys
              .deep_reject { |k, _| !k.start_with?('$') && k.exclude?(c_path) }
              .deep_transform_keys { |k| k.gsub(c_path, 'data') }
          end

          final_projection_stage = {
            'data.id' => ['$data', concept_id].compact_blank.join('.'),
            'data.name' => ['$data', concept_name].compact_blank.join('.'),
            'data.parent_id' => ['$data', concept_parent_id].compact_blank.join('.'),
            'data.uri' => ['$data', concept_uri].compact_blank.join('.'),
            'data.priority' => priority
          }

          proj_match_unwind_phases = []
          array_positions.each_with_index do |position, index|
            current_full_concept_path = ["dump.#{locale}", concept_path.split('.')[0..index].join('.')].compact_blank.join('.')
            proj_match_unwind_phases << { '$project' => { 'data' => ["$#{current_full_concept_path}"].compact_blank.join('.')}} if index.zero?
            proj_match_unwind_phases << { '$project' => { 'data' => ["$data.#{concept_path.split('.')[index]}"].compact_blank.join('.')}} unless index.zero?
            next unless position == 1
            proj_match_unwind_phases << { '$unwind' => '$data' }
            proj_match_unwind_phases << { '$match' => create_post_unwind_source_filter_stage.call(current_full_concept_path) }
          end

          pipelines = []
          pipelines += [{
            '$match' => source_filter_stage
          }] + proj_match_unwind_phases + [
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
            },
            {
              '$match' => { 'id' => { '$ne' => nil }, 'name' => { '$ne' => nil } }
            },
            {
              '$addFields' => {
                'name' => { '$toString' => '$name'},
                'id' => { '$toString' => '$id'}
              }
            }
          ]

          trim_name = options[:download].key?(:trim_name) ? options.dig(:download, :trim_name) : true
          if trim_name
            pipelines << {
              '$addFields' => {
                'name' => { '$trim' => { 'input' => '$name' } }
              }
            }
          end

          data_id_prefix = options.dig(:download, :data_id_prefix)

          raise ArgumentError, 'data_id_prefix and external_id_prefix cannot be present together' if data_id_prefix.present? && options.dig(:download, :external_id_prefix).present?
          if data_id_prefix.present?
            pipelines << {
              '$addFields' => {
                'id' => { '$concat' => [data_id_prefix, { '$toString' => '$id' }] }
              }
            }
          end

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              pipelines,
              allow_disk_use: true
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

        def self.path_config(key, options)
          suffix = [key.to_s, 'path'].compact_blank.join('_')

          options.dig(:download, :"concept_#{suffix}") || options.dig(:download, :"data_#{suffix}")
        end
      end
    end
  end
end
