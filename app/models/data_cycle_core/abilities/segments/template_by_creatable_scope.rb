# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class TemplateByCreatableScope < Base
        attr_reader :subject, :scopes

        def initialize(scopes)
          @scopes = Array.wrap(scopes).map(&:to_s)
          @subject = DataCycleCore::Thing
        end

        def include?(obj, scope, _content = nil)
          return obj&.creatable?(scope) if scopes.include?('all')

          obj&.creatable?(scope) && scopes.include?(scope)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
