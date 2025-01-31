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
            'collection' => Differs::Collection,
            'timeseries' => Differs::Timeseries,
            'table' => Differs::Table,
            'oembed' => Differs::Oembed
          }
        end

        def diff(a, b, template, partial_update)
          @diff_hash = {}
          cleaned_a = DataCycleCore::DataHashService.normalize_datahash(a)
          cleaned_b = DataCycleCore::DataHashService.normalize_datahash(b)

          template.each do |key, value|
            next if value&.dig('type')&.in?(['key'])

            item_template = value['type'] == 'object' ? value&.dig('properties') : value
            diff_key = basic_types[value['type']].new(cleaned_a&.dig(key), cleaned_b&.dig(key), item_template, '', partial_update).diff_hash
            @diff_hash[key] = diff_key if diff_key.present?
          end

          @diff_hash
        end
      end
    end
  end
end
