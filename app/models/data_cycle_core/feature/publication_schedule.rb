# frozen_string_literal: true

module DataCycleCore
  module Feature
    class PublicationSchedule < Base
      class << self
        def available?(content = nil)
          enabled? && attribute_keys(content).present?
        end

        def publication_template(content)
          @publication_template ||= DataCycleCore::Thing.find_by(template: true, template_name: content&.schema&.dig('properties', attribute_keys(content).first, 'template_name'))
        end

        def publication_date_key(content)
          publication_template(content)&.property_definitions&.select do |k, v|
            v['type'] == 'datetime' &&
              DataCycleCore.internal_classification_attributes.exclude?(k)
          end&.keys&.first
        end

        def classification_tree_labels(content)
          publication_template(content)&.property_definitions&.select do |k, v|
            v['type'] == 'classification' &&
              DataCycleCore.internal_classification_attributes.exclude?(k)
          end&.transform_values do |v|
            v['tree_label']
          end
        end
      end
    end
  end
end
