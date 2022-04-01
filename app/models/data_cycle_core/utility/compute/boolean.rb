# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Boolean
        class << self
          def classification(computed_parameters:, content:, key:, **_args)
            classification_id = DataCycleCore::ClassificationAlias.classification_for_tree_with_name(computed_parameters.last&.dig('tree_label'), computed_parameters.last&.dig('name'))

            return if classification_id.blank?

            if computed_parameters.first.nil?
              content.try(key)
            else
              Array.wrap(computed_parameters.first).include?(classification_id)
            end
          end
        end
      end
    end
  end
end
