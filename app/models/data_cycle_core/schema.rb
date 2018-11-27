# frozen_string_literal: true

module DataCycleCore
  class Schema
    def self.content_types
      DataCycleCore::Thing.where(template: true).map(&:schema).map { |schema| schema['content_type'] }.uniq
    end

    def self.templates_with_content_type(content_type)
      DataCycleCore::Thing.where(template: true).where("schema ->> 'content_type' = '#{content_type}'")
    end
  end
end
