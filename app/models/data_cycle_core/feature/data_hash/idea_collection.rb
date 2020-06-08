# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module IdeaCollection
        def self.prepended(base)
          base.before_save_data_hash :change_life_cycle_stage, if: proc {
            @new_content &&
              try(:is_part_of).present? &&
              template_name == DataCycleCore::Feature::IdeaCollection.template_name &&
              !parent.life_cycle_stage?(DataCycleCore::Feature::IdeaCollection.life_cycle_stage(self))
          }
        end

        private

        def change_life_cycle_stage
          parent.set_life_cycle_classification(DataCycleCore::Feature::IdeaCollection.life_cycle_stage(self), @current_user)
        end
      end
    end
  end
end
