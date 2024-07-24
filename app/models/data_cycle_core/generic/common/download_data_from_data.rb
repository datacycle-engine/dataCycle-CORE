# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadDataFromData
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data_from_data(
            download_object: utility_object,
            iterator: method(:load_data_from_mongo).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:
          )
        end

        def self.load_data_from_mongo(options:, lang:, source_filter:)
          raise ArgumentError, 'missing read_type for loading location ranges' if options.dig(:download, :read_type).nil?
          read_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type])

          data_name = options.dig(:download, :data_name_path) || nil
          data_id = options.dig(:download, :data_id_path) || data_name

          data_path = options.dig(:download, :data_path)
          data_id_path = [data_id].compact_blank.join('.')
          data_name_path = [data_name].compact_blank.join('.')
          additional_data_paths = options.dig(:download, :additional_data_paths) || []

          source_filter_stage = {
            '$and' => [
              { "dump.#{lang}" => { '$exists' => true } }
            ]
          }
          source_filter.each do |filter|
            source_filter_stage['$and'].push(filter.deep_stringify_keys)
          end

          project_filter_stage = {
            'data' => ['$dump', lang, data_path].compact_blank.join('.')
          }
          additional_data_paths.each do |attr|
            project_filter_stage[attr[:name]] = ['$dump', lang, attr[:path]].compact_blank.join('.')
          end

          id_fallback_fields = [['$data', data_id_path].compact_blank.join('.'), ['$data', data_name_path].compact_blank.join('.')] + additional_data_paths.map { |attr| "$data.#{attr[:path]}" }
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
            mongo.collection.aggregate([
                                         {
                                           # '$match' => { "dump.#{lang}" => { '$exists' => true } }.merge(source_filter.deep_stringify_keys)
                                           '$match' => source_filter_stage
                                         },
                                         {
                                           '$project' => project_filter_stage
                                         },
                                         {
                                           '$unwind' => '$data'
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
