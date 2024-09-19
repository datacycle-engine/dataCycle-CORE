# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByIds < Base
        attr_reader :subject, :conditions, :ids

        def initialize(*thing_ids)
          @thing_ids = Array.wrap(thing_ids).flatten.map(&:to_s)
          @subject = DataCycleCore::Thing
          @conditions = { id: @thing_ids }
        end

        private

        def to_restrictions(**)
          to_restriction(thing_ids: @thing_ids.map { |v| I18n.t("thingy_ids.#{v}", default: v, locale:) }.join(', '))
        end
      end
    end
  end
end
