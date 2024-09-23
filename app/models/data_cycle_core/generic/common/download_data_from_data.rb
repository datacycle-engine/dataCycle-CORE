# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadDataFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_data_from_mongo).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:
          )
        end

        def self.credentials?
          false
        end

        def self.load_data_from_mongo(options:, locale:, source_filter:, **_keyword_args)
          raise ArgumentError, 'missing read_type for loading location ranges' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(
            DataCycleCore::Generic::Collection2, collection: options[:download][:read_type]
          )

          data_name = options.dig(:download, :data_name_path) || nil
          data_id = options.dig(:download, :data_id_path) || data_name

          data_path = options.dig(:download, :data_path)
          data_id_path = [data_id].compact_blank.join('.')
          data_name_path = [data_name].compact_blank.join('.')
          additional_data_paths = options.dig(:download, :additional_data_paths) || []

          full_data_path = ["dump.#{locale}", data_path].compact_blank.join('.')
          full_id_path = [full_data_path, data_id_path].compact_blank.join('.')
          source_filter_stage = { full_id_path => { '$ne' => nil } }.with_indifferent_access
          source_filter_stage.merge!(source_filter) if source_filter.present?

          post_unwind_source_filter_stage = source_filter_stage
            .deep_stringify_keys
            .deep_reject { |k, _| !k.start_with?('$') && k.exclude?(full_data_path) }
            .deep_transform_keys { |k| k.gsub(full_data_path, 'data') }

          project_filter_stage = {
            'data' => ['$dump', locale, data_path].compact_blank.join('.')
          }
          additional_data_paths.each do |attr|
            project_filter_stage[attr[:name]] = ['$dump', locale, attr[:path]].compact_blank.join('.')
          end

          id_fallback_fields = [
            ['$data', data_id_path].compact_blank.join('.'),
            ['$data', data_name_path].compact_blank.join('.')
          ] + additional_data_paths.map { |attr| "$data.#{attr[:path]}" }

          add_fields_stage = {
            'data.id' => { '$ifNull' => id_fallback_fields},
            'data.name' => ['$data', data_name_path].compact_blank.join('.')
          }
          additional_data_paths.each do |attr|
            add_fields_stage["data.#{attr[:name]}"] = "$#{attr[:name]}"
          end

          group_stage = {
            '_id' => '$data.id', 'data' => { '$first' => '$data'}
          }

          DataCycleCore::Generic::Collection2.with(read_type) do |mongo|
            mongo.collection.aggregate(
              [
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
                }
              ], allow_disk_use: true
            ).to_a
          end
        end

        def self.data_id(data)
          data.dig('id').to_s
        end

        def self.data_name(data)
          data.dig('name')
        end
      end
    end
  end
end
