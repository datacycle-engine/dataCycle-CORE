# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # This module provides functionality for downloading and processing data from a MongoDB source.
      #
      # Here an example of all options that can be used in the configuration file. Note that not all options are required or can be used together.
      # ```yaml
      # options:
      #   # data_path defines the path to the data in the document. '[]' must be added to any part of the path that is an array. It will be removed for the query.
      #   data_path: 'data.field[].items[]'
      #   # data_id_path defines the path to the id of the data in the document. It is relative to data_path. The default value is 'id'.
      #   data_id_path: 'custom_id'
      #   data_id_path: ~ # if the value of the data path should be used
      #   # data_name_path defines the path to the name of the data in the document. It is relative to data_path. The default value is the value of data_id_path. Can be ERB template.
      #   data_name_path: 'custom_name'
      #   data_name_path: '<%= 'name_' + locale %>' # ERB template
      #   data_name_path: ~ # if the value of the data path should be used
      #   # data_name_path_fallback defines the fallback paths to the name of the data in the document. They are relative to data_path. Can be ERB template.
      #   data_name_path_fallback:
      #     - 'name_fallback1'
      #     - '<%= 'name.' + locale %>'
      #   # additional_data_paths can be used to add additional fields to the data, e.g. the id of the root document. Must be relative to the root document.
      #   additional_data_paths:
      #     name_add1: 'attribute1'
      #     name_add2: 'attribute3'
      #   # attribute_whitelist can be used to only save certain attributes to the database. The values of 'data_id' and 'data_name' as well as 'additional_paths' will be added automatically. Cannot be used with attribute_blacklist.
      #   attribute_whitelist: ['extra1', 'extra2']
      #   # attribute_blacklist can be used to remove certain attributes from the data before saving to the database. Cannot be used with attribute_whitelist.
      #   attribute_blacklist: ['attribute3']
      #   # data_id_prefix can be used to add a prefix to the id of the data before saving to the database. Cannot be used with external_id_prefix.
      #   data_id_prefix: 'prefix_'
      #   # external_id_prefix cannot be used with data_id_prefix. Does not change the id and will be saved as a separate field.
      #   external_id_prefix: 'prefix_'
      #   # trim_name can be used to trim the name of the data before saving to the database. It will remove leading and trailing whitespace. The default value is true.
      #   trim_name: true
      # ```
      module DownloadDataFromData
        extend Extensions::DownloadFromData

        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_data_from_mongo).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :data_id_transformation)],
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
          data_name_path_fallback = paths[:data_name_path_fallback]
          # full_data_path = paths[:full_data_path]
          full_id_path = paths[:full_id_path]
          additional_paths = paths[:additional_paths]

          source_filter_stage = { full_id_path => { '$exists' => true } }.with_indifferent_access
          source_filter_stage.merge!(source_filter) if source_filter.present?

          proj_match_unwind_phases = []
          path_array_positions.each_with_index do |position, index|
            current_full_name_path = ["dump.#{locale}", data_path.split('.')[0..index].join('.')].compact_blank.join('.')
            project_stage = if index.zero?
                              {
                                'data' => ["$#{current_full_name_path}"].compact_blank.join('.'),
                                'add_data' => additional_paths
                              }
                            else
                              {
                                'data' => ["$data.#{data_path.split('.')[index]}"].compact_blank.join('.'),
                                'add_data' => '$add_data'
                              }
                            end

            proj_match_unwind_phases << { '$project' => project_stage }

            next unless position == 1
            proj_match_unwind_phases << { '$unwind' => '$data' }
            proj_match_unwind_phases << { '$match' => create_post_unwind_match_stage(path: current_full_name_path, source_filter_stage:) }
          end

          id_fallback_fields = [
            ['$data', data_id_path].compact_blank.join('.'),
            ['$data', data_name_path].compact_blank.join('.')
          ].uniq

          name_fallback_fields = [
            ['$data', data_name_path].compact_blank.join('.')
          ] + data_name_path_fallback.map do |name|
            ['$data', name].compact_blank.join('.')
          end
          name_fallback_fields.uniq!

          add_fields_stage = {}

          if id_fallback_fields.many?
            add_fields_stage['data.id'] = { '$ifNull' => id_fallback_fields }
          else
            add_fields_stage['data.id'] = id_fallback_fields.first
          end

          if name_fallback_fields.many?
            add_fields_stage['data.name'] = { '$ifNull' => name_fallback_fields }
          else
            add_fields_stage['data.name'] = name_fallback_fields.first
          end

          additional_paths.each_key do |name|
            if name == 'external_system'
              add_fields_stage["data.#{name}"] = "$#{name}"
            else
              # prevent overwriting of existing data fields
              add_fields_stage["data.#{name}"] = { '$ifNull' => ["$data.#{name}", "$add_data.#{name}"] }
            end
          end

          group_stage = {
            '_id' => '$data.id', 'data' => { '$first' => '$data'}
          }

          pipelines = [
            {
              '$match' => source_filter_stage
            }
          ] + proj_match_unwind_phases + [
            {
              '$addFields' => add_fields_stage
            },
            {
              '$group' => group_stage
            },
            {
              '$replaceRoot' => { 'newRoot' => '$data' }
            }
          ]

          trim_name = options[:download].key?(:trim_name) ? options.dig(:download, :trim_name) : true
          if trim_name == true
            pipelines << {
              '$addFields' => {
                'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } }
              }
            }
          end

          attribute_whitelist = Array.wrap(options.dig(:download, :attribute_whitelist)) if options.dig(:download, :attribute_whitelist).present?
          attribute_blacklist = Array.wrap(options.dig(:download, :attribute_blacklist)) if options.dig(:download, :attribute_blacklist).present?

          raise ArgumentError, 'attribute_whitelist and attribute_blacklist cannot be present together' if attribute_whitelist.present? && attribute_blacklist.present?
          if attribute_whitelist.present?
            attribute_whitelist += ['id', 'name'] + additional_paths.keys
            attribute_whitelist.uniq!
            pipelines << { '$project' => attribute_whitelist.index_with { |_attr| 1 } }
          elsif attribute_blacklist.present?
            pipelines << { '$project' => attribute_blacklist.index_with { |_attr| 0 } }
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

          pipelines <<  {
            '$match' => { 'id' => { '$ne' => nil } }
          }

          pipelines
        end

        def self.prepare_data_paths(options:, locale:)
          paths = {}
          data_name_path_fallback = []
          data_id = options[:download].key?(:data_id_path) ? options.dig(:download, :data_id_path) : 'id'
          data_name = options[:download].key?(:data_name_path) ? options.dig(:download, :data_name_path) : data_id
          I18n.with_locale(locale.to_sym) do
            data_name = data_name&.then { |v| ERB.new(v).result(binding) }
            data_name_path_fallback = Array.wrap(options.dig(:download, :data_name_path_fallback)).map { |v| ERB.new(v).result(binding) }
          end

          data_path = options.dig(:download, :data_path) || ''
          data_path += '[]' unless data_path.end_with?('[]')
          path_array_positions = data_path.split('.').map { |x| x.include?('[]') ? 1 : 0 }
          data_path = data_path.gsub('[]', '')

          data_id_path = [data_id].compact_blank.join('.')
          data_name_path = [data_name].compact_blank.join('.')

          full_data_path = ["dump.#{locale}", data_path].compact_blank.join('.')
          full_id_path = [full_data_path, data_id_path].compact_blank.join('.')

          additional_data_paths = options.dig(:download, :additional_data_paths) || []
          additional_paths = {}

          if additional_data_paths.is_a?(Array)
            additional_data_paths.each do |attr|
              additional_paths[attr[:name].to_s] = ['$dump', locale, attr[:path]].compact_blank.join('.')
            end
          elsif additional_data_paths.is_a?(Hash)
            additional_data_paths.each do |name, path|
              additional_paths[name.to_s] = ['$dump', locale, path].compact_blank.join('.')
            end
          end

          additional_paths['external_system'] = '$external_system'

          paths[:data_path] = data_path
          paths[:path_array_positions] = path_array_positions
          paths[:data_id_path] = data_id_path
          paths[:data_name_path] = data_name_path
          paths[:data_name_path_fallback] = data_name_path_fallback
          paths[:full_data_path] = full_data_path
          paths[:full_id_path] = full_id_path
          paths[:additional_paths] = additional_paths
          paths.with_indifferent_access
        end
      end
    end
  end
end
