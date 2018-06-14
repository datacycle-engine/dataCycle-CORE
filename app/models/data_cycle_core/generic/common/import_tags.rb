# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportTags
        def self.import_data(utility_object:, options:)
          raise 'Missing configuration attribute "tree_label"' if options.dig(:import, :tree_label).blank?
          raise 'Missing configuration attribute "tag_id_path"' if options.dig(:import, :tag_id_path).blank?
          raise 'Missing configuration attribute "tag_name_path"' if options.dig(:import, :tag_name_path).blank?

          DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
            utility_object,
            options.dig(:import, :tree_label),
            method(:load_root_classifications).to_proc,
            ->(_, _, _) { [] },
            ->(_, _) { nil },
            method(:extract_data).to_proc,
            options
          )
        end

        def self.load_root_classifications(mongo_item, locale, options)
          mongo_item.collection.aggregate(mongo_item.where(:_id.ne => nil)
            .unwind(
              "dump.#{locale}.#{parse_common_tag_path(options).join('.')}"
            ).project(
              "dump.#{locale}.id": "$dump.#{locale}.#{options.dig(:import, :tag_id_path)}",
              "dump.#{locale}.tag": "$dump.#{locale}.#{options.dig(:import, :tag_name_path)}"
            ).group(
              _id: "$dump.#{locale}.id",
              :dump.first => '$dump'
            ).pipeline)
        end

        def self.extract_data(options, raw_data)
          external_id =
            case options.dig(:import, :external_id_hash_method)
            when 'MD5'
              Digest::MD5.new.update(raw_data['id']).hexdigest
            else
              raw_data['id']
            end

          {
            external_key: "#{options.dig(:import, :external_id_prefix)}#{external_id}",
            name: raw_data['tag']
          }
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            tree_label = options.dig(:import, :tree_label)
            keywords = unwind_project_data(
              raw_data,
              parse_common_tag_path(options),
              options.dig(:import, :tag_id_path).split('.'),
              options.dig(:import, :tag_name_path).split('.')
            )
            return if keywords&.compact.blank?

            keywords.each do |keyword_hash|
              classification_data = extract_data(options, keyword_hash).merge(tree_name: tree_label)
              DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                utility_object: utility_object,
                classification_data: classification_data,
                parent_classification_alias: nil
              )
            end
          end
        end

        def self.parse_common_tag_path(options)
          options.dig(:import, :tag_id_path).split('.')
            .zip(options.dig(:import, :tag_name_path).split('.'))
            .take_while { |id_component, name_component| id_component == name_component }
            .map(&:first)
        end

        def self.unwind_project_data(raw_data, common_path, id_path, name_path)
          return nil if raw_data&.dig(*common_path).blank?
          if raw_data&.dig(*common_path).is_a?(::Array)
            raw_data.dig(*common_path).map do |item|
              id_value = (id_path - common_path).blank? ? item : item.dig(*(id_path - common_path))
              name_value = (id_path - common_path).blank? ? item : item.dig(*(name_path - common_path))
              { 'id' => id_value, 'tag' => name_value }
            end
          else
            [{ 'id' => raw_data.dig(*id_path), 'tag' => raw_data.dig(*name_path) }]
          end
        end
      end
    end
  end
end
