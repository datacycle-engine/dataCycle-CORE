# frozen_string_literal: true

module DataCycleCore
  module Feature
    class IdeaCollection < Base
      class << self
        def template_name(content = nil)
          configuration(content).dig('template')
        end

        def template(content = nil)
          DataCycleCore::Thing.find_by(template: true, template_name: template_name(content))
        end

        def life_cycle_stage(content = nil)
          DataCycleCore::Feature::LifeCycle.ordered_classifications(content).dig(configuration(content).dig('life_cycle_stage'), :id)
        end

        def life_cycle_stage_name(content = nil)
          configuration(content).dig('life_cycle_stage')
        end
      end
    end
  end
end
