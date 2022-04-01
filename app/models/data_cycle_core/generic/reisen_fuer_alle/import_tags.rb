# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ReisenFuerAlle
      module ImportTags
        def self.import_data(utility_object:, options:)
          raise 'Missing configuration attribute "tree_label"' if options.dig(:import, :tree_label).blank?
          raise 'Missing configuration attribute "tag_id_path"' if options.dig(:import, :tag_id_path).blank?
          raise 'Missing configuration attribute "tag_name_path"' if options.dig(:import, :tag_name_path).blank?
          raise 'Missing configuration attribute "tag_uri_path"' if options.dig(:import, :tag_uri_path).blank?

          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_, _, _) { nil },
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, options)
          mongo_item.collection.aggregate(mongo_item.where(:_id.ne => nil)
            .unwind(
              ['dump', locale.to_s, parse_common_tag_path(options)].flatten.join('.')
            ).project(
              "dump.#{locale}.id": "$dump.#{locale}.#{options.dig(:import, :tag_id_path)}",
              "dump.#{locale}.tag": "$dump.#{locale}.#{options.dig(:import, :tag_name_path)}",
              "dump.#{locale}.uri": "$dump.#{locale}.#{options.dig(:import, :tag_uri_path)}"
            ).group(
              _id: "$dump.#{locale}.id",
              :dump.first => '$dump'
            ).pipeline)
        end

        def self.extract_data(options, raw_data)
          external_id = raw_data['id']
          name = raw_data['tag']
          uri = raw_data['uri']
          {
            external_key: "#{options.dig(:import, :external_id_prefix)}#{external_id}",
            name: name,
            uri: uri
          }
        end

        def self.parse_common_tag_path(options)
          return options.dig(:import, :tag_path) if options.dig(:import, :tag_path).present?
          options.dig(:import, :tag_id_path).split('.')
            .zip(options.dig(:import, :tag_name_path).split('.'))
            .take_while { |id_component, name_component| id_component == name_component }
            .map(&:first)
        end
      end
    end
  end
end
