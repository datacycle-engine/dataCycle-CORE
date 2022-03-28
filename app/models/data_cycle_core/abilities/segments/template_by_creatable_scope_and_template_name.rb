# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class TemplateByCreatableScopeAndTemplateName < Base
        attr_reader :subject, :scopes, :template_names

        def initialize(scopes, template_names)
          @scopes = Array.wrap(scopes).map(&:to_s)
          @template_names = Array.wrap(template_names).map(&:to_s)
          @subject = DataCycleCore::Thing
        end

        def include?(obj, scope, _content = nil)
          return obj&.creatable?(scope) && template_names.include?(obj.template_name) if scopes.include?('all')

          obj&.creatable?(scope) && scopes.include?(scope) && template_names.include?(obj.template_name)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
