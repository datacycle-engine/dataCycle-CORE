# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttributeAllowed < Base
        attr_reader :subject

        def initialize
          @subject = DataCycleCore::DataAttribute
        end

        def include?(attribute)
          [
            attribute_not_disabled(attribute),
            attribute_not_in_overlay(attribute),
            attribute_not_external(attribute),
            attribute_not_releasable(attribute),
            attribute_tree_label_visible(attribute)
          ].all?
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        def attribute_not_disabled(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', attribute.scope.to_s, 'disabled').to_s != 'true'
        end

        def attribute_not_in_overlay(attribute)
          !DataCycleCore::Feature::Overlay.allowed?(attribute.content) ||
            !DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
        end

        def attribute_not_external(attribute)
          return true if attribute.scope.to_s != 'edit' # only restricted in edit scope
          return true if attribute.content.try(:external_source_id).present?

          attribute.definition.dig('external').to_s != 'true'
        end

        def attribute_not_releasable(attribute)
          return true if attribute.scope.to_s != 'show' # only restricted in show scope

          !DataCycleCore::Feature::Releasable.attribute_keys(attribute.content).include?(attribute.key.attribute_name_from_key)
        end

        def attribute_tree_label_visible(attribute)
          return true if attribute.scope.to_s != 'edit' # only restricted in edit scope
          return true if attribute.definition.dig('global')
          return true if attribute.definition.dig('tree_label').blank? # only for classification type attributes

          tree_label_external_id = DataCycleCore::ClassificationTreeLabel.find_by(name: attribute.definition['tree_label'])&.external_source_id

          return true if tree_label_external_id.blank?

          tree_label_external_id == attribute.content.try(:external_source_id)
        end
      end
    end
  end
end
