# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module LegacyLinkFunctions
          def self.add_link(data_hash, attribute, content_type, external_source_id, key_function, condition_function = nil)
            return data_hash if condition_function.present? && !condition_function.call(data_hash)

            data_hash.merge(
              {
                attribute => find_thing_ids(external_system_id: external_source_id, external_key: key_function.call(data_hash), content_type:, limit: 1).presence
              }
            )
          end

          def self.add_links(data_hash, attribute, content_type, external_source_id, key_function, condition_function = nil)
            return data_hash if condition_function.present? && !condition_function.call(data_hash)

            key_function_values = key_function.call(data_hash) || []

            data_hash.merge(
              {
                attribute => find_thing_ids(external_system_id: external_source_id, external_key: key_function_values, content_type:)
              }
            )
          end

          def self.add_universal_classifications(data_hash, function)
            universal_classifications(data_hash, function)
          end

          def self.universal_classifications(data_hash, function)
            data_hash['universal_classifications'] ||= []
            data_hash['universal_classifications'] += function.call(data_hash) || []
            data_hash
          end

          def self.tags_to_ids(data_hash, attribute, external_source_id, external_prefix, condition_function = nil)
            return data_hash if condition_function.present? && !condition_function.call(data_hash)

            if data_hash[attribute].blank?
              data_hash[attribute] = []
            else
              data_hash[attribute] = DataCycleCore::Classification.where(external_source_id:, external_key: data_hash[attribute].map { |a| "#{external_prefix}#{a}" }).pluck(:id)
            end

            data_hash
          end

          def self.tags_to_ids_by_name(data_hash, attribute, tree_label)
            if data_hash[attribute].blank?
              data_hash[attribute] = []
            else
              data_hash[attribute] = DataCycleCore::Classification.includes(primary_classification_alias: [classification_tree: :classification_tree_label]).where('lower(classifications.name) IN (?)', data_hash[attribute]&.map(&:downcase)).where(primary_classification_alias: { classification_trees: { classification_tree_labels: { name: tree_label } } }).ids
            end
            data_hash
          end

          def self.category_key_to_ids(data_hash, attribute, data_list, _name, external_source_id, external_prefix, key)
            return data_hash if data_hash.blank? || data_list.blank?

            data_hash.merge(
              {
                attribute =>
                  data_list.call(data_hash)&.map { |item_data|
                    search_params = {
                      external_source_id:,
                      external_key: external_prefix + item_data.dig(key)
                    }
                    DataCycleCore::Classification.find_by(search_params)&.id
                  }&.reject(&:nil?) || []
              }
            )
          end

          def self.load_category(data_hash, attribute, external_source_id, external_key)
            data_hash.merge(
              {
                attribute => [
                  DataCycleCore::Classification.find_by(
                    external_source_id:, external_key: external_key.call(data_hash)
                  )&.id
                ].compact.presence
              }
            )
          end

          def self.add_user_link(data_hash, attribute, key_function)
            return data_hash if key_function.call(data_hash).blank?
            data_hash.merge({ attribute => DataCycleCore::User.find_by(email: key_function.call(data_hash))&.id })
          end

          def self.find_thing_ids(external_system_id:, external_key:, content_type: DataCycleCore::Thing, limit: nil, pluck_id: true)
            return [] if external_key.blank?

            if content_type == DataCycleCore::Thing
              query = DataCycleCore::Thing
                .by_external_key(external_system_id, external_key, 'thing_external_systems')
                .order(
                  [
                    Arel.sql(
                      'array_position(ARRAY[?]::varchar[], thing_external_systems.external_key::varchar)'
                    ),
                    external_key
                  ]
                )
            else
              query = content_type.where(external_source_id: external_system_id, external_key:).order(
                [
                  Arel.sql("array_position(ARRAY[?]::varchar[], #{content_type.table_name}.external_key::varchar)"),
                  external_key
                ]
              )
            end

            query = query.limit(limit) if limit.present?
            query = query.pluck(:id) if pluck_id
            query
          end
        end
      end
    end
  end
end
