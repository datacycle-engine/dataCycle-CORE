# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class TemplateByCreatableScopeExceptTemplateName < Base
        attr_reader :subject, :scopes, :template_names

        def initialize(scopes, template_names)
          @scopes = Array.wrap(scopes).map(&:to_s)
          @template_names = Array.wrap(template_names).map(&:to_s)
          @subject = DataCycleCore::Thing
        end

        def include?(obj, scope, _content = nil)
          return obj&.creatable?(scope) && template_names.exclude?(obj.template_name) if scopes.include?('all')

          obj&.creatable?(scope) && scopes.include?(scope) && template_names.exclude?(obj.template_name)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          to_restriction(
            scopes: scopes.map { |scope| I18n.t("abilities.scopes.#{scope}", locale:) }.join(', '),
            template_names: template_names.map { |v| I18n.t("template_names.#{v}", default: v, locale:) }.join(', ')
          )
        end
      end
    end
  end
end
