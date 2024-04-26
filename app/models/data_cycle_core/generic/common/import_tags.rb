# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportTags
        module ClassMethods
          def import_data(utility_object:, options:)
            raise 'Missing configuration attribute "tree_label"' if options.dig(:import, :tree_label).blank?
            raise 'Missing configuration attribute "tag_id_path"' if options.dig(:import, :tag_id_path).blank?
            raise 'Missing configuration attribute "tag_name_path"' if options.dig(:import, :tag_name_path).blank?

            DataCycleCore::Generic::Common::ImportFunctions.import_classifications(
              utility_object,
              options.dig(:import, :tree_label),
              method(:load_root_classifications).to_proc,
              ->(_, _, _) { [] },
              ->(_, _, _) {},
              method(:extract_data).to_proc,
              options
            )
          end

          def load_root_classifications(mongo_item, locale, options)
            options = options.with_evaluated_values
            source_filter = options.dig(:import, :source_filter) || {}

            attribute_name = ['dump', locale, options.dig(:import, :tag_path) || options.dig(:import, :tag_id_path)].join('.')
            path_array = ['dump', locale.to_s, parse_common_tag_path(options)].flatten.join('.').split('.')

            aggregation = mongo_item
              .where({ attribute_name => { '$ne' => nil } }.merge(source_filter))

            (1..path_array.size)
              .each { |n| aggregation = aggregation.unwind(path_array.take(n).join('.')) }

            aggregation = aggregation.where(source_filter)

            project_hash = {
              "dump.#{locale}.id": "$dump.#{locale}.#{options.dig(:import, :tag_id_path)}",
              "dump.#{locale}.tag": "$dump.#{locale}.#{options.dig(:import, :tag_name_path)}"
            }
            project_hash["dump.#{locale}.desc"] = "$dump.#{locale}.#{options.dig(:import, :tag_description_path)}" if options.dig(:import, :tag_description_path).present?
            project_hash["dump.#{locale}.uri"] = "$dump.#{locale}.#{options.dig(:import, :tag_uri_path)}" if options.dig(:import, :tag_uri_path).present?
            aggregation = aggregation.project(project_hash)

            aggregation = aggregation.group(
              _id: "$dump.#{locale}.id",
              :dump.first => '$dump'
            ).pipeline
            aggregation << { '$match' => { '_id' => { '$ne' => nil } } }
            mongo_item.collection.aggregate(aggregation)
          end

          def extract_data(options, raw_data)
            external_id =
              case options.dig(:import, :external_id_hash_method)
              when 'MD5'
                Digest::MD5.new.update(raw_data['id']).hexdigest
              when 'round'
                raw_data['id']&.to_f&.round
              else
                raw_data['id']
              end
            name =
              case options.dig(:import, :tag_name_function)
              when 'round'
                raw_data['tag']&.to_f&.round
              else
                raw_data['tag'].is_a?(::Array) ? raw_data['tag'].join(', ') : raw_data['tag']
              end
            name ||= 'unknown'
            description = raw_data['desc']&.to_s
            uri = raw_data['uri']&.to_s
            value_hash = {
              external_key: "#{options.dig(:import, :external_id_prefix)}#{external_id}",
              name:
            }
            value_hash[:description] = description if description.present?
            value_hash[:uri] = uri if uri.present?
            value_hash
          end

          def process_content(utility_object:, raw_data:, locale:, options:)
            return if options&.blank? || options.dig(:import).blank?
            allowed_locales = options.dig(:import, :locales) || utility_object.external_source.try(:default_options)&.symbolize_keys&.dig(:locales) || [locale]
            return unless allowed_locales.include?(locale)

            I18n.with_locale(locale) do
              tree_label = options.dig(:import, :tree_label)
              keywords = unwind_project_data(
                raw_data,
                parse_common_tag_path(options),
                options.dig(:import, :tag_id_path).split('.'),
                options.dig(:import, :tag_name_path).split('.'),
                options.dig(:import, :tag_description_path)&.split('.'),
                options.dig(:import, :tag_uri_path)&.split('.')
              )
              return if keywords&.compact.blank?

              keywords.each do |keyword_hash|
                classification_data = extract_data(options, keyword_hash).merge(tree_name: tree_label)
                DataCycleCore::Generic::Common::ImportFunctions.import_classification(
                  utility_object:,
                  classification_data:,
                  parent_classification_alias: nil
                )
              end
            end
          end

          def parse_common_tag_path(options)
            return options.dig(:import, :tag_path) if options.dig(:import, :tag_path).present?
            options.dig(:import, :tag_id_path).split('.')
              .zip(options.dig(:import, :tag_name_path).split('.'))
              .take_while { |id_component, name_component| id_component == name_component }
              .map(&:first)
          end

          def unwind_project_data(raw_data, common_path, id_path, name_path, desc_path = nil, uri_path = nil)
            if common_path.blank?
              default_values = [{ 'id' => raw_data.dig(*(id_path.presence || [nil])), 'tag' => raw_data.dig(*(name_path.presence || [nil])) }]
              default_values[0]['desc'] = raw_data.dig(*desc_path) if desc_path.present?
              default_values[0]['uri'] = raw_data.dig(*uri_path) if uri_path.present?
              return default_values
            end

            return nil if raw_data&.dig(*common_path).blank?
            if raw_data&.dig(*common_path).is_a?(::Array)
              raw_data.dig(*common_path).map do |item|
                id_value = (id_path - common_path).blank? ? item : item.dig(*(id_path - common_path))
                name_value = (id_path - common_path).blank? ? item : item.dig(*(name_path - common_path))
                c_hash = { 'id' => id_value, 'tag' => name_value }
                if desc_path.present?
                  desc_value = (id_path - common_path).blank? ? item : item.dig(*(desc_path - common_path))
                  c_hash['desc'] = desc_value
                end
                if uri_path.present?
                  uri_value = (id_path - common_path).blank? ? item : item.dig(*(uri_path - common_path))
                  c_hash['uri'] = uri_value
                end
                c_hash
              end
            else
              default_values = [{ 'id' => raw_data.dig(*(id_path.presence || [nil])), 'tag' => raw_data.dig(*(name_path.presence || [nil])) }]
              default_values[0]['desc'] = raw_data.dig(*desc_path) if desc_path.present?
              default_values[0]['uri'] = raw_data.dig(*uri_path) if uri_path.present?
              default_values
            end
          end
        end

        extend ClassMethods
      end
    end
  end
end
