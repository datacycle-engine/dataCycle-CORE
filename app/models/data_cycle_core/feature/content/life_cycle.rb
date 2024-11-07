# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module LifeCycle
        def life_cycle_changed?
          life_cycle_changed
        end

        def life_cycle_stage
          @life_cycle_stage ||= try(DataCycleCore::Feature::LifeCycle.attribute_keys(self)&.first)&.first
        end

        def life_cycle_stage?(stage_id)
          life_cycle_stage&.id == stage_id
        end

        def life_cycle_stage_name?(stage_name)
          life_cycle_stage&.name == stage_name
        end

        def life_cycle_classification?(classification_id)
          DataCycleCore::Feature::LifeCycle.ordered_classifications(self)&.values&.pluck(:id)&.include?(classification_id)
        end

        def life_cycle_stage_index(classification_id = life_cycle_stage&.id)
          DataCycleCore::Feature::LifeCycle.ordered_classifications(self)&.values&.pluck(:id)&.index(classification_id)
        end

        def icon_type
          base_type = super

          return base_type unless DataCycleCore::Feature::LifeCycle.allowed?(self) &&
                                  DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(self).present? &&
                                  content_type?('container')

          "#{base_type}_#{life_cycle_stage&.name&.underscore_blanks}"
        end
      end
    end
  end
end
