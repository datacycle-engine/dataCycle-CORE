# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class Object < Basic
        def basic_types
          {
            'object' => Differs::Object,
            'string' => Differs::String,
            'slug' => Differs::Slug,
            'number' => Differs::Number,
            'date' => Differs::Date,
            'datetime' => Differs::Datetime,
            'boolean' => Differs::Boolean,
            'geographic' => Differs::Geographic,
            'linked' => Differs::Linked,
            'embedded' => Differs::Embedded,
            'asset' => Differs::Asset,
            'classification' => Differs::Classification,
            'schedule' => Differs::Schedule,
            'opening_time' => Differs::Schedule,
            'collection' => Differs::Collection
          }
        end

        def diff(a, b, template, partial_update)
          @diff_hash = {}
          cleaned_a = a&.dc_deep_transform_values { |v| blank?(v) ? nil : v }
          cleaned_b = b&.dc_deep_transform_values { |v| blank?(v) ? nil : v }

          template.each do |key, key_item|
            next if key_item&.dig('type')&.in?(['key', 'timeseries'])
            item_template = key_item['type'] == 'object' ? key_item&.dig('properties') : key_item
            diff_key = basic_types[key_item['type']].new(cleaned_a&.dig(key), cleaned_b&.dig(key), item_template, '', partial_update).diff_hash
            @diff_hash[key] = diff_key if diff_key.present?
          end

          diff_hash
        end
      end
    end
  end
end
