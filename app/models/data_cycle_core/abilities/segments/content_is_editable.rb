# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ContentIsEditable < Base
        attr_reader :subject, :method_names

        def initialize(*method_names)
          @subject = DataCycleCore::Thing
          @method_names = Array.wrap(method_names).flatten(1).map { |m| Array.wrap(m) }
        end

        def include?(content, scope = nil)
          return true if method_names.blank?

          method_names.any? do |m|
            method_name = m.first
            method_params = method(method_name).parameters

            kwargs = method_params.select { |param| param[0] == :keyreq }.map { |param| param[1] }

            if kwargs.include?(:scope)
              send(method_name, content, *m[1..-1], scope:)
            else
              send(method_name, content, *m[1..-1])
            end
          end
        end

        def by_scope_and_template_name?(content, config, scope:)
          return false if scope.blank?
          content.template_name.in? Array.wrap(config[scope])
        end

        def content_not_external?(content)
          content.try(:external_source_id).blank?
        end

        def content_overlay_allowed?(content)
          DataCycleCore::Feature::Overlay.allowed?(content)
        end

        def content_global_property_names_present?(content)
          content.global_property_names.present?
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        def to_restrictions(**)
          Array.wrap(method_names).map { |v| I18n.t("abilities.content_is_editable_method_names.#{v}", locale:) }
        end
      end
    end
  end
end
