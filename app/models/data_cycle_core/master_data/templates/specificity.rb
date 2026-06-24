# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      # Value object defining the scope of a mixin.
      # @param name_prefix [String] e.g. "Health" for "HealthMixin.yml"
      # @param content_set_name [String] e.g. "creative_works" for "creative_works/HealthMixin.yml"
      class Specificity
        GENERIC = 0
        CONTENT_SET = 1
        TEMPLATE = 2

        attr_reader :specificity_value, :set_name, :template_name

        def initialize(name_prefix:, content_set_name:)
          @specificity_value = determine_specificity(name_prefix, content_set_name)
          @set_name = @specificity_value == CONTENT_SET && name_prefix.present? ? name_prefix.to_sym : content_set_name
          @template_name = @specificity_value == TEMPLATE ? name_prefix : nil
        end

        private

        def determine_specificity(name_prefix, content_set_name)
          return GENERIC if name_prefix.blank? && content_set_name.blank?

          if name_prefix.present? && TemplateImporter::CONTENT_SETS.exclude?(name_prefix)
            TEMPLATE
          elsif name_prefix.present? || content_set_name.present?
            CONTENT_SET
          else
            GENERIC
          end
        end
      end
    end
  end
end
