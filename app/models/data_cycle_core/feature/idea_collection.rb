# frozen_string_literal: true

module DataCycleCore
  module Feature
    class IdeaCollection < Base
      class << self
        def data_hash_module
          DataCycleCore::Feature::DataHash::IdeaCollection
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::IdeaCollection
        end

        def template_name(content = nil)
          configuration(content)['template']
        end

        def template(content = nil)
          DataCycleCore::Thing.new(template_name: template_name(content))
        end

        def life_cycle_stage(content = nil)
          DataCycleCore::Feature::LifeCycle.ordered_classifications(content).dig(configuration(content)['life_cycle_stage'], :id)
        end

        def life_cycle_stage_name(content = nil)
          configuration(content)['life_cycle_stage']
        end
      end
    end
  end
end
