# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class ThingByTemplateName < Base
        attr_reader :subject, :conditions

        def initialize(*template_names)
          @subject = DataCycleCore::Thing
          @conditions = { template_name: Array.wrap(template_names).flatten.map(&:to_s) }
        end
      end
    end
  end
end
