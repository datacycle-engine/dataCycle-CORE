# frozen_string_literal: true

module DataCycleCore
  module BulkUpdateTypes
    extend ActiveSupport::Concern

    private

    def transform_exisiting_values(bulk_edit_types, template_hash, data_hash, content)
      bulk_edit_types&.each do |k, v|
        if v.include?('add')
          data_hash[k] = get_content_value(k, template_hash, content) + data_hash[k]
        elsif v.include?('remove')
          data_hash[k] = get_content_value(k, template_hash, content) - data_hash[k]
        end
      end

      data_hash
    end

    def get_content_value(key, template_hash, content)
      case template_hash.dig('properties', key, 'type')
      when 'classification'
        content.try(key)&.ids || []
      else
        content.try(key)
      end
    end
  end
end
