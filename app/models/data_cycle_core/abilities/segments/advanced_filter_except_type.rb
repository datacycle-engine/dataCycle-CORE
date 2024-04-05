# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AdvancedFilterExceptType < Base
        attr_reader :subject, :except_types

        def initialize(subject, except_types = [])
          @except_types = Array.wrap(except_types).map(&:to_s)
          @subject = Array.wrap(subject).map(&:to_sym)
        end

        def include?(_view, _name = nil, type = nil, *args)
          return false if type.to_s == 'classification_alias_ids' && !args.first&.dig(:data, :visible)

          except_types.exclude?(type.to_s)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end

        private

        def to_restrictions(**)
          return if except_types.blank?

          to_restriction(except: Array.wrap(except_types).map { |v| I18n.t("filter_groups.#{v}", locale:) }.join(', '))
        end
      end
    end
  end
end
