# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Classification
        class << self
          def keywords(**args)
            tags = args.dig(:computed_parameters).presence&.try(:flatten)&.reject(&:blank?)
            return if tags.blank?
            DataCycleCore::Classification.find(tags)&.map(&:name)&.join(',')
          end

          def description(**args)
            classification_ids = args.dig(:computed_parameters).presence&.try(:flatten)&.reject(&:blank?)
            return if classification_ids.blank?
            DataCycleCore::Classification
              .find(classification_ids)
              &.map(&:classification_aliases)
              &.flatten
              &.uniq
              &.map { |classification_alias| classification_alias.description || classification_alias.name || classification_alias.internal_name }
              &.join(',')
          end
        end
      end
    end
  end
end
