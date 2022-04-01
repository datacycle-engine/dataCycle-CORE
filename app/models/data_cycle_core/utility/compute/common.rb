# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Common
        class << self
          def copy(computed_parameters:, **_args)
            computed_parameters.values.first
          end

          def get_values_from_hash(data_hash, key_path)
            return data_hash if key_path.blank?

            if data_hash.is_a?(::Hash)
              key = key_path.first

              if data_hash.key?(key) || data_hash.dig('datahash')&.key?(key) || data_hash.dig('translations', I18n.locale.to_s)&.key?(key)
                value = data_hash.dig(key) || data_hash.dig('datahash', key) || data_hash.dig('translations', I18n.locale.to_s, key)
              else
                id = data_hash.dig('id') || data_hash.dig('datahash', 'id') || data_hash.dig('translations', I18n.locale.to_s, 'id')
                value = DataCycleCore::Thing.find_by(id: id)&.attribute_to_h(key)
              end

              get_values_from_hash(value, key_path.drop(1))
            elsif data_hash.is_a?(::Array) && data_hash.first.is_a?(ActiveRecord::Base) || data_hash.is_a?(ActiveRecord::Relation)
              data_hash.map { |v| get_values_from_hash({ key_path.first => v.attribute_to_h(key_path.first) }, key_path) }
            elsif data_hash.is_a?(::Array) && data_hash.first.to_s.uuid?
              DataCycleCore::Thing.where(id: data_hash).map { |v| get_values_from_hash({ key_path.first => v.attribute_to_h(key_path.first) }, key_path) }
            elsif data_hash.is_a?(::Array)
              data_hash.map { |v| get_values_from_hash(v, key_path) }
            end
          end
        end
      end
    end
  end
end
