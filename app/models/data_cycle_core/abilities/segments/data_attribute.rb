# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttribute < Base
        attr_reader :subject, :method_names, :except_list

        def initialize(method_names, except_list = {})
          @subject = DataCycleCore::DataAttribute
          @method_names = Array.wrap(method_names).map(&:to_sym)
          @except_list = except_list
        end

        def include?(attribute)
          method_names.all? { |method_name| send(method_name, attribute) }
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        def attribute_not_disabled?(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', attribute.scope.to_s, 'disabled').to_s != 'true'
        end

        def attribute_not_read_only?(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', attribute.scope.to_s, 'readonly').to_s != 'true'
        end

        def overlay_attribute_visible?(attribute)
          return true unless DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
          return true if attribute.content.try(:external_source_id).present? && DataCycleCore::Feature::Overlay.allowed?(attribute.content)

          false
        end

        def attribute_not_releasable?(attribute)
          !DataCycleCore::Feature::Releasable.attribute_keys(attribute.content).include?(attribute.key.attribute_name_from_key)
        end

        def attribute_not_included_in_publication_schedule?(attribute)
          return true unless DataCycleCore::Feature::PublicationSchedule.allowed?(attribute.content)
          !(
            (attribute.key =~ Regexp.union(*DataCycleCore.features.dig(:publication_schedule, :classification_keys))) &&
              !DataCycleCore::Feature::PublicationSchedule.includes_attribute_key(attribute.content, attribute.key)
          )
        end

        def attribute_not_external?(attribute)
          attribute.definition.dig('global').to_s == 'true' || attribute.definition.dig('external').to_s != 'true'
        end

        def attribute_tree_label_visible?(attribute)
          return true if attribute.definition.dig('global')
          return true if attribute.definition.dig('tree_label').blank? # only for classification type attributes

          tree_label_external_id = DataCycleCore::ClassificationTreeLabel.find_by(name: attribute.definition['tree_label'])&.external_source_id

          return true if tree_label_external_id.blank?

          tree_label_external_id == attribute.content.try(:external_source_id)
        end

        def attribute_not_excluded?(attribute)
          except_list.dig(attribute.content.template_name.to_sym)&.include?(attribute.key.attribute_name_from_key) != true
        end
      end
    end
  end
end
