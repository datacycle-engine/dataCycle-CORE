# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # This module is used to download concepts from data.
      #
      # Here an example of all options that can be used in the configuration file. Note that not all options are required or can be used together.
      #
      # Note: you can use the options with 'data_' prefix or 'concept_' prefix. Preferably use 'data_' prefix.
      # ```yaml
      # options:
      #   # data_path defines the path to the data in the document. '[]' must be added to any part of the path that is an array. It will be removed for the query.
      #   data_path: 'data.field[].items[]'
      #   # data_id_path defines the path to the id of the data in the document. It is relative to data_path. The default value is the value of data_name_path.
      #   data_id_path: 'custom_id'
      #   data_id_path: ~ # if the value of the data path should be used
      #   # data_name_path defines the path to the name of the data in the document. It is relative to data_path. The default value is the value of data_id_path. Can be ERB template.
      #   data_name_path: 'custom_name'
      #   data_name_path: '<%= 'name_' + locale %>' # ERB template
      #   data_name_path: ~ # if the value of the data path should be used
      #   # data_parent_id_path defines the path to the parent id of the data in the document. It is relative to data_path. The default value is 'parent_id'.
      #   data_parent_id_path: 'custom_parent_id'
      #   # priority defines the priority of the data. It is used decied which document to keep in case the same id is found in different documents. The default value is 5.
      #   data_priority: 5
      #   # data_uri_path defines the path to the uri of the data in the document. The default value is 'uri'.
      #   data_uri_path: 'custom_uri'
      #   # data_id_prefix defines the prefix to be added to the id of the data. It is used to avoid conflicts with other data. The default value is nil. Cannot be used with data_external_id_prefix.
      #   data_id_prefix: 'prefix_'
      #   # data_external_id_prefix defines the prefix to be added to the external id of the data. It is used to avoid conflicts with other data. The default value is nil.
      #   data_external_id_prefix: 'prefix_'
      # ```
      module DownloadConceptsFromData
        extend Extensions::DownloadFromData

        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_data_from_mongo).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :external_id_hash_method)],
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false,
            cleanup_data: method(:cleanup_data).to_proc.curry[options.dig(:download, :cleanup_data)]
          )
        end

        def self.create_aggregate_pipeline(options:, locale:, source_filter:)
          paths = prepare_data_paths(options:, locale:)
          data_path = paths[:data_path]
          path_array_positions = paths[:path_array_positions]
          data_id_path = paths[:data_id_path]
          data_name_path = paths[:data_name_path]
          # full_data_path = paths[:full_data_path]
          full_id_path = paths[:full_id_path]
          concept_parent_id = paths[:concept_parent_id]
          priority = paths[:priority]
          concept_uri = paths[:concept_uri]

          source_filter_stage = { full_id_path => { '$exists' => true } }.with_indifferent_access
          source_filter_stage.merge!(source_filter) if source_filter.present?

          final_projection_stage = {
            'data.id' => ['$data', data_id_path].compact_blank.join('.'),
            'data.name' => ['$data', data_name_path].compact_blank.join('.'),
            'data.parent_id' => ['$data', concept_parent_id].compact_blank.join('.'),
            'data.uri' => ['$data', concept_uri].compact_blank.join('.'),
            'data.priority' => priority
          }

          proj_match_unwind_phases = []
          path_array_positions.each_with_index do |position, index|
            current_full_concept_path = ["dump.#{locale}", data_path.split('.')[0..index].join('.')].compact_blank.join('.')
            proj_match_unwind_phases << { '$project' => { 'data' => ["$#{current_full_concept_path}"].compact_blank.join('.')}} if index.zero?
            proj_match_unwind_phases << { '$project' => { 'data' => ["$data.#{data_path.split('.')[index]}"].compact_blank.join('.')}} unless index.zero?
            next unless position == 1
            proj_match_unwind_phases << { '$unwind' => '$data' }
            proj_match_unwind_phases << { '$match' => create_post_unwind_match_stage(path: current_full_concept_path, source_filter_stage:) }
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

          pipelines <<  {
            '$match' => { 'id' => { '$ne' => nil }, 'name' => { '$ne' => nil } }
          }

          data_id_prefix = options.dig(:download, :data_id_prefix)
          raise ArgumentError, 'data_id_prefix and external_id_prefix cannot be present together' if data_id_prefix.present? && options.dig(:download, :external_id_prefix).present?
          if data_id_prefix.present?
            pipelines << {
              '$addFields' => {
                'id' => { '$concat' => [data_id_prefix, '$id'] },
                **(concept_parent_id.present? ? { 'parent_id' => { '$concat' => [data_id_prefix, '$parent_id'] } } : {})
              }
            }
          end
          pipelines
        end

        def self.prepare_data_paths(options:, locale:)
          paths = {}

          concept_name = nil
          I18n.with_locale(locale.to_sym) do
            concept_name = path_config(:name, options)&.then { |v| ERB.new(v).result(binding) }
          end
          # either both concept_name_path and concept_id_path should be present or none, hence the fallbacks
          concept_id = path_config(:id, options) || concept_name
          concept_name ||= concept_id

          concept_parent_id = path_config(:parent_id, options) || 'parent_id'
          priority = options.dig(:download, :priority) || 5
          concept_uri = path_config(:uri, options) || 'uri'

          concept_path = path_config(nil, options) || ''
          concept_path += '[]' unless concept_path.end_with?('[]')
          path_array_positions = concept_path.split('.').map { |x| x.include?('[]') ? 1 : 0 }
          concept_path = concept_path.gsub('[]', '')

          concept_id_path = [concept_id].compact_blank.join('.')
          concept_name_path = [concept_name].compact_blank.join('.')
          # concept_parent_id_path = [concept_path, concept_parent_id].compact_blank.join('.')
          # concept_uri_path = [concept_path, concept_uri].compact_blank.join('.')

          full_data_path = ["dump.#{locale}", concept_path].compact_blank.join('.')
          full_id_path = [full_data_path, concept_id].compact_blank.join('.')

          paths[:data_path] = concept_path
          paths[:path_array_positions] = path_array_positions
          # paths[:data_id] = concept_id
          # paths[:data_name] = concept_name
          paths[:data_id_path] = concept_id_path
          paths[:data_name_path] = concept_name_path
          paths[:full_data_path] = full_data_path
          paths[:full_id_path] = full_id_path
          paths[:concept_parent_id] = concept_parent_id
          paths[:priority] = priority
          paths[:concept_uri] = concept_uri
          paths.with_indifferent_access
        end

        def self.path_config(key, options)
          suffix = [key.to_s, 'path'].compact_blank.join('_')

          options.dig(:download, :"concept_#{suffix}") || options.dig(:download, :"data_#{suffix}")
        end
      end
    end
  end
end
