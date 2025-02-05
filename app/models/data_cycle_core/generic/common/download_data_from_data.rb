# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadDataFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_data_from_mongo).to_proc,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :data_id_transformation)],
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_data_from_mongo(options:, locale:, source_filter:, **_keyword_args)
          raise ArgumentError, "missing read_type for #{options.dig(:download, :name)}" if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(
            DataCycleCore::Generic::Collection2, collection: options[:download][:read_type]
          )

          data_id = options[:download].key?(:data_id_path) ? options.dig(:download, :data_id_path) : 'id'
          data_name = options[:download].key?(:data_name_path) ? options.dig(:download, :data_name_path) : data_id

          data_path = options.dig(:download, :data_path)
          data_id_path = [data_id].compact_blank.join('.')
          data_name_path = [data_name].compact_blank.join('.')
          additional_data_paths = options.dig(:download, :additional_data_paths) || []

          attribute_whitelist = Array.wrap(options.dig(:download, :attribute_whitelist)) + ['id', 'name'] if options.dig(:download, :attribute_whitelist).present?

          full_data_path = ["dump.#{locale}", data_path].compact_blank.join('.')
          full_id_path = [full_data_path, data_id_path].compact_blank.join('.')
          source_filter_stage = { full_id_path => { '$exists' => true } }.with_indifferent_access
          source_filter_stage.merge!(source_filter) if source_filter.present?

          post_unwind_source_filter_stage = source_filter_stage
            .deep_stringify_keys
            .deep_reject { |k, _| !k.start_with?('$') && k.exclude?(full_data_path) }
            .deep_transform_keys { |k| k.gsub(full_data_path, 'data') }

          project_filter_stage = {
            'data' => ['$dump', locale, data_path].compact_blank.join('.')
          }

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

          additional_paths[:external_system] = '$external_system'

          project_filter_stage.merge!(additional_paths)

          id_fallback_fields = [
            ['$data', data_id_path].compact_blank.join('.'),
            ['$data', data_name_path].compact_blank.join('.')
          ] + additional_paths.values

          add_fields_stage = {
            'data.id' => { '$ifNull' => id_fallback_fields},
            'data.name' => ['$data', data_name_path].compact_blank.join('.')
          }
          additional_paths.each_key do |name|
            add_fields_stage["data.#{name}"] = "$#{name}"
          end

          group_stage = {
            '_id' => '$data.id', 'data' => { '$first' => '$data'}
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
              '$addFields' => add_fields_stage
            },
            {
              '$group' => group_stage
            },
            {
              '$replaceRoot' => { 'newRoot' => '$data' }
            },
            {
              '$match' => { 'id' => { '$ne' => nil } }
            }
          ]

          pipelines << { '$project' => attribute_whitelist.index_with { |_attr| 1 } } if attribute_whitelist.present?

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              pipelines, allow_disk_use: true
            ).to_a
          end
        end

        def self.data_id(data_id_transformation, data)
          id = data['id'].to_s
          id = data_id_transformation[:module].safe_constantize.public_send(data_id_transformation[:method], id) if data_id_transformation.present?

          id
        end

        def self.data_name(data)
          data['name']
        end
      end
    end
  end
end
