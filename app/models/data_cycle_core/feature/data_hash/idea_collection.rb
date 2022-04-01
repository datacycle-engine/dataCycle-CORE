# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module IdeaCollection
        def after_save_data_hash(options)
          super

          change_life_cycle_stage(current_user: options.current_user) if options.new_content &&
                                                                         template_name == DataCycleCore::Feature::IdeaCollection.template_name &&
                                                                         !try(:is_part_of).nil? &&
                                                                         !parent.life_cycle_stage?(DataCycleCore::Feature::IdeaCollection.life_cycle_stage(self))
        end

        private

        def change_life_cycle_stage(current_user:)
          parent.set_life_cycle_classification(DataCycleCore::Feature::IdeaCollection.life_cycle_stage(self), current_user)
        end
      end
    end
  end
end
