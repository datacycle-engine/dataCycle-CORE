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
            iterate_credentials: false,
            cleanup_data: method(:cleanup_data).to_proc.curry[options.dig(:download, :cleanup_data)]
          )
        end

        def self.load_data_from_mongo(options:, locale:, source_filter:, **_keyword_args)
          raise ArgumentError, "missing read_type for #{options.dig(:download, :name)}" if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(
            DataCycleCore::Generic::Collection2, collection: options[:download][:read_type]
          )

          data_name_fallback = []
          data_id = options[:download].key?(:data_id_path) ? options.dig(:download, :data_id_path) : 'id'
          data_name = options[:download].key?(:data_name_path) ? options.dig(:download, :data_name_path) : data_id
          I18n.with_locale(locale.to_sym) do
            data_name = data_name&.then { |v| ERB.new(v).result(binding) }
            data_name_fallback = Array.wrap(options.dig(:download, :data_name_path_fallback)).each { |v| ERB.new(v).result(binding) }
          end

          data_path = options.dig(:download, :data_path)
          data_id_path = [data_id].compact_blank.join('.')
          data_name_path = [data_name].compact_blank.join('.')
          additional_data_paths = options.dig(:download, :additional_data_paths) || []

          attribute_whitelist = Array.wrap(options.dig(:download, :attribute_whitelist)) + ['id', 'name'] if options.dig(:download, :attribute_whitelist).present?
          attribute_blacklist = Array.wrap(options.dig(:download, :attribute_blacklist)) if options.dig(:download, :attribute_blacklist).present?

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

          additional_paths['external_system'] = '$external_system'

          project_filter_stage.merge!(additional_paths)

          id_fallback_fields = [
            ['$data', data_id_path].compact_blank.join('.'),
            ['$data', data_name_path].compact_blank.join('.')
          ] + additional_paths.values

          name_fallback_fields = [
            ['$data', data_name_path].compact_blank.join('.')
          ] + data_name_fallback.map do |name|
            ['$data', name].compact_blank.join('.')
          end

          add_fields_stage = {
            'data.id' => { '$toString' => { '$ifNull' => id_fallback_fields } }
          }

          if name_fallback_fields.length > 1
            add_fields_stage['data.name'] = { '$ifNull' => name_fallback_fields }
          else
            add_fields_stage['data.name'] = name_fallback_fields.first
          end

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

          trim_name = options[:download].key?(:trim_name) ? options.dig(:download, :trim_name) : true
          if trim_name
            pipelines << {
              '$addFields' => {
                'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } }
              }
            }
          end

          raise ArgumentError, 'attribute_whitelist and attribute_blacklist cannot be present together' if attribute_whitelist.present? && attribute_blacklist.present?
          if attribute_whitelist.present?
            pipelines << { '$project' => attribute_whitelist.index_with { |_attr| 1 } }
          elsif attribute_blacklist.present?
            pipelines << { '$project' => attribute_blacklist.index_with { |_attr| 0 } }
          end

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              pipelines, allow_disk_use: true
            ).to_a
          end
        end

        def self.data_id(data_id_transformation, data)
          if data_id_transformation.present?
            id = data_id_transformation[:module]
              .safe_constantize
              .public_send(data_id_transformation[:method], data)
          else
            id = data['id'].to_s
          end

          id
        end

        def self.data_name(data)
          data['name']
        end

        def self.cleanup_data(cleanup_data_config, data)
          return data if cleanup_data_config.blank? || cleanup_data_config[:module].blank? || cleanup_data_config[:method].blank?

          cleanup_data_config[:module].safe_constantize.public_send(cleanup_data_config[:method], data)
        end
      end
    end
  end
end
