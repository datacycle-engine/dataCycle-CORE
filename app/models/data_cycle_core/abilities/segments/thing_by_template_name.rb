# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByTemplateName < Base
        attr_reader :subject, :conditions, :template_names

        def initialize(*template_names)
          @template_names = Array.wrap(template_names).flatten.map(&:to_s)
          @subject = DataCycleCore::Thing
          @conditions = { template_name: @template_names }
        end

        private

        def to_restrictions(**)
          to_restriction(template_names: template_names.map { |v| I18n.t("template_names.#{v}", default: v, locale:) }.join(', '))
        end
      end
    end
  end
end
