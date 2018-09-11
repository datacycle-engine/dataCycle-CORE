# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Object < Basic
        def basic_types
          {
            'object' => Differs::Object,
            # 'key' => Differs::Key,
            'string' => Differs::String,
            'number' => Differs::Number,
            'datetime' => Differs::Datetime,
            'boolean' => Differs::Boolean,
            'geographic' => Differs::Geographic,
            'linked' => Differs::Linked,
            'embedded' => Differs::Embedded,
            'asset' => Differs::Asset,
            'classification' => Differs::Classification
          }
        end

        def diff(a, b, template)
          @diff_hash = {}
          template.each do |key, key_item|
            next if key_item&.dig('type') == 'key'
            item_template = key_item['type'] == 'object' ? key_item&.dig('properties') : key_item
            diff_key = basic_types[key_item['type']].new(a&.dig(key), b&.dig(key), item_template).diff_hash
            @diff_hash[key] = diff_key if diff_key.present?
          end
          diff_hash
        end
      end
    end
  end
end
