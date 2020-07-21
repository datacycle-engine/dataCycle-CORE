# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TileBorderColor < Base
      class << self
        def class_string(content)
          return '' unless enabled? && configuration.dig('tree_label').present? && content.respond_to?(:classification_aliases)

          content&.classification_aliases&.to_a&.filter { |c| c.classification_tree_label&.name == 'Eyebase - Status' }&.map { |c| "#{c.classification_tree_label&.name}_#{c.internal_name}".underscore_blanks }&.join(' ')
        end
      end
    end
  end
end
