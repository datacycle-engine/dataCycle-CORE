# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class DataAttribute < Base
        attr_reader :subject, :method_names, :except_list

        def initialize(method_names = [], except_list = {})
          @subject = DataCycleCore::DataAttribute
          @method_names = Array.wrap(method_names).map { |m| Array.wrap(m) }
          @except_list = except_list.to_h
        end

        def include?(attribute)
          method_names.all? { |m| send(m.first, attribute, *m[1..-1]) }
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        def attribute_content_not_external?(attribute)
          !attribute.content.external?
        end

        def attribute_content_external?(attribute)
          attribute.content.external?
        end

        def attribute_not_disabled?(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', attribute.scope.to_s, 'disabled').to_s != 'true'
        end

        def attribute_not_read_only?(attribute)
          attribute.definition.deep_stringify_keys.dig('ui', attribute.scope.to_s, 'readonly').to_s != 'true'
        end

        def attribute_is_in_overlay?(attribute)
          attribute.content&.external? &&
            DataCycleCore::Feature::Overlay.allowed?(attribute.content) &&
            DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
        end

        def overlay_attribute_visible?(attribute)
          return true unless DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
          return true if attribute.content&.external? && DataCycleCore::Feature::Overlay.allowed?(attribute.content)

          false
        end

        def attribute_not_releasable?(attribute)
          DataCycleCore::Feature::Releasable.attribute_keys(attribute.content).exclude?(attribute.key.attribute_name_from_key)
        end

        def attribute_not_included_in_publication_schedule?(attribute)
          return true unless DataCycleCore::Feature::PublicationSchedule.allowed?(attribute.content)
          !(
            (attribute.key =~ Regexp.union(*DataCycleCore.features.dig(:publication_schedule, :classification_keys))) &&
              !DataCycleCore::Feature::PublicationSchedule.includes_attribute_key(attribute.content, attribute.key)
          )
        end

        def attribute_not_external?(attribute)
          attribute.definition.dig('global').to_s == 'true' || attribute.definition.dig('local').to_s == 'true' || attribute.definition.dig('external').to_s != 'true'
        end

        def attribute_tree_label_visible?(attribute)
          return true if attribute.definition.dig('global')
          return true if attribute.definition.dig('local')
          return true if attribute.definition.dig('tree_label').blank? # only for classification type attributes

          tree_label_external_id = DataCycleCore::ClassificationTreeLabel.find_by(name: attribute.definition['tree_label'])&.external_source_id

          return true if tree_label_external_id.blank?

          tree_label_external_id == attribute.content.try(:external_source_id)
        end

        def attribute_not_excluded?(attribute)
          attribute_and_template_not_blacklisted?(attribute, except_list)
        end

        def template_whitelisted?(attribute, template_names = [])
          attribute.content.template_name.in?(Array.wrap(template_names))
        end

        def template_not_blacklisted?(attribute, template_names = [])
          !template_whitelisted?(attribute, template_names)
        end

        def attribute_whitelisted?(attribute, attribute_names = [])
          Array.wrap(attribute_names).any? { |a| Array.wrap(a).all? { |v| attribute.key.attribute_path_from_key.include?(v) } }
        end

        def attribute_not_blacklisted?(attribute, attribute_names = [])
          !attribute_whitelisted?(attribute, attribute_names)
        end

        def attribute_and_template_whitelisted?(attribute, whitelist = {})
          whitelist.to_h.with_indifferent_access.dig(attribute.content.template_name)&.then { |v| Array.wrap(v).include?(attribute.key.attribute_name_from_key) }
        end

        def attribute_and_template_not_blacklisted?(attribute, blacklist = {})
          !attribute_and_template_whitelisted?(attribute, blacklist)
        end

        def attribute_type_whitelisted?(attribute, whitelist = [])
          attribute.definition&.[]('type')&.in?(whitelist)
        end

        def attribute_type_not_blacklisted?(attribute, blacklist = [])
          !attribute.definition&.[]('type')&.in?(blacklist)
        end

        def content_created_by_user?(attribute)
          attribute.content.try(:created_by) == user.id
        end

        def attribute_value_present?(attribute)
          attribute.content.try(attribute.key.attribute_name_from_key)&.present?
        end

        def attribute_value_blank?(attribute)
          !attribute_value_present?(attribute)
        end
      end
    end
  end
end
