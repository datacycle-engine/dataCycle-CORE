# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        class << self
          def copy(computed_parameters:, **_args)
            computed_parameters.values.first
          end

          def take_first(computed_parameters:, computed_definition:, **_args)
            computed_parameters.each do |_, val|
              return val if val.present?
            end

            return [] if computed_definition.dig('type')&.in?(['embedded', 'linked', 'classification'])

            nil
          end

          def get_values_from_hash(data_hash, key_path, filter = nil)
            return data_hash if key_path.blank?
            return if data_hash.blank?

            if data_hash.is_a?(::Hash)
              key = key_path.first

              if data_hash.key?(key) || data_hash.dig('datahash')&.key?(key) || data_hash.dig('translations', I18n.locale.to_s)&.key?(key)
                value = data_hash.dig(key) || data_hash.dig('datahash', key) || data_hash.dig('translations', I18n.locale.to_s, key)
              else
                id = data_hash.dig('id') || data_hash.dig('datahash', 'id') || data_hash.dig('translations', I18n.locale.to_s, 'id')
                item = DataCycleCore::Thing.find_by(id: id)
                value = item.respond_to?(key) ? item.attribute_to_h(key) : nil
              end

              return if key_path.one? && filter.present? && !data_in_filter?(data_hash, filter)

              get_values_from_hash(value, key_path.drop(1), filter)
            elsif data_hash.is_a?(::Array) && data_hash.first.is_a?(ActiveRecord::Base) || data_hash.is_a?(ActiveRecord::Relation)
              data_hash.map { |v| get_values_from_hash({ key_path.first => v.respond_to?(key_path.first) ? v.attribute_to_h(key_path.first) : nil, 'id' => v.id }, key_path, filter) }
            elsif data_hash.is_a?(::Array) && data_hash.first.to_s.uuid?
              DataCycleCore::Thing.where(id: data_hash).map { |v| get_values_from_hash({ key_path.first => v.respond_to?(key_path.first) ? v.attribute_to_h(key_path.first) : nil, 'id' => v.id }, key_path, filter) }
            elsif data_hash.is_a?(::Array)
              data_hash.map { |v| get_values_from_hash(v, key_path, filter) }
            end
          end

          def attribute_value_by_first_match(computed_parameters:, computed_definition:, **_args)
            Array.wrap(computed_definition.dig('compute', 'value')).each do |config|
              value = Array.wrap(get_values_from_hash(computed_parameters, config['attribute'].split('.'), config['filter'])).compact.first

              return value if DataCycleCore::DataHashService.present?(value)
            end

            nil
          end

          private

          def data_in_filter?(data, filter)
            return true unless data.is_a?(::Hash)

            Array.wrap(filter).each do |config|
              in_filter = case config['type']
                          when 'classification'
                            id = DataCycleCore::ClassificationAlias.joins(:classification_alias_path).find_by(classification_alias_path: { full_path_names: config['value'].split('>').map(&:strip).reverse })&.primary_classification&.id
                            next false if id.nil?

                            Array.wrap(config['key']).any? { |k| Array.wrap(get_values_from_hash(data, [k])).include?(id) }
                          else
                            get_values_from_hash(data, [config['type']]) == config['value']
                          end

              return false unless in_filter
            end

            true
          end
        end
      end
    end
  end
end
