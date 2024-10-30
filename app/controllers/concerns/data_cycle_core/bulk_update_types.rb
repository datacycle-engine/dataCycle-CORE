# frozen_string_literal: true

module DataCycleCore
  module BulkUpdateTypes
    extend ActiveSupport::Concern

    private

    def transform_exisiting_values(bulk_edit_types, template_hash, data_hash, content)
      data_hash[:datahash] ||= {}

      bulk_edit_types[:datahash]&.each do |k, v|
        data_hash[:datahash][k] ||= nil

        if v.include?('add')
          data_hash[:datahash][k] = get_content_value(k, template_hash, content) + data_hash[:datahash][k]
        elsif v.include?('remove')
          data_hash[:datahash][k] = get_content_value(k, template_hash, content) - data_hash[:datahash][k]
        end
      end

      data_hash
    end

    def get_content_value(key, template_hash, content)
      case template_hash.dig('properties', key, 'type')
      when 'classification'
        content.try(key)&.pluck(:id) || []
      else
        content.try(key)
      end
    end
  end
end
