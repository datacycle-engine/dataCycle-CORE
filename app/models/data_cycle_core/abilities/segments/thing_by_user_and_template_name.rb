# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByUserAndTemplateName < Base
        attr_reader :subject, :user_attribute_name, :template_names

        def initialize(user_attribute_name, *template_names)
          @subject = DataCycleCore::Thing
          @template_names = Array.wrap(template_names).flatten.map(&:to_s)
          @user_attribute_name = user_attribute_name
        end

        def conditions
          { template_name: template_names, user_attribute_name.to_sym => user&.id }
        end

        private

        def to_restrictions(subject:, **)
          to_restriction(
            attribute_name: subject.human_attribute_name(user_attribute_name, locale:),
            template_names: template_names.map { |v| I18n.t("template_names.#{v}", default: v, locale:) }.join(', ')
          )
        end
      end
    end
  end
end
