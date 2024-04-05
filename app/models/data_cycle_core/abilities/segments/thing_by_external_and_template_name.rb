# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByExternalAndTemplateName < Base
        attr_reader :subject, :template_names

        def initialize(template_names)
          @template_names = Array.wrap(template_names).map(&:to_s)
          @subject = DataCycleCore::Thing
        end

        def include?(thing, _content = nil)
          thing&.external? && thing&.template_name.in?(template_names)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          to_restriction(template_names: template_names.map { |v| I18n.t("template_names.#{v}", default: v, locale:) }.join(', '))
        end
      end
    end
  end
end
