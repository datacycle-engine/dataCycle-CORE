# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TileBorderColor < Base
      class << self
        def class_string(content)
          return unless enabled? && configuration[:tree_label].present? && content.respond_to?(:classification_aliases)
          return unless configuration[:template_name].blank? || content&.template_name&.in?(Array.wrap(configuration[:template_name]))

          content&.classification_aliases&.to_a&.filter { |c| c.classification_tree_label&.name == configuration[:tree_label] }&.map { |c| "#{c.classification_tree_label&.name}_#{c.internal_name}".underscore_blanks }&.join(' ')
        end
      end
    end
  end
end
