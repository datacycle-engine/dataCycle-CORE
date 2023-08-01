# frozen_string_literal: true

module DataCycleCore
  module Feature
    class PublicationSchedule < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::PublicationSchedule
        end

        def available?(content = nil)
          enabled? && attribute_keys(content).present?
        end

        def publication_template(content)
          @publication_template ||= DataCycleCore::Thing.new(template_name: content&.schema&.dig('properties', attribute_keys(content).first, 'template_name'))
        end

        def publication_date_key(content)
          publication_template(content)&.property_definitions&.select { |_k, v|
            v['type'] == 'date'
          }&.keys&.first
        end

        def classification_tree_labels(content)
          publication_template(content)&.property_definitions&.select { |_k, v|
            v['type'] == 'classification' && (Array(DataCycleCore::ClassificationTreeLabel.find_by(name: v['tree_label'])&.visibility) & ['show', 'show_more']).size.positive?
          }&.transform_values do |v|
            v['tree_label']
          end
        end
      end
    end
  end
end
