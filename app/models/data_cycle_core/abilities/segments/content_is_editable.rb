# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ContentIsEditable < Base
        attr_reader :subject, :method_names

        def initialize(*method_names)
          @subject = DataCycleCore::Thing
          @method_names = Array.wrap(method_names).flatten.map(&:to_sym)
        end

        def include?(content, _scope = nil)
          method_names.any? { |method_name| send(method_name, content) }
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
