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

          def value(**args)
            values = args.dig(:computed_parameters).presence&.try(:flatten)
            return unless values.size == 1
            args.dig(:data_hash).dig('translated_classification') || DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(values.first.dig('tree'), values.first.dig('value'))
          end
        end
      end
    end
  end
end
