# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module LifeCycle
        def set_life_cycle_classification(classification_tree_label, classification_id, user)
          set_data_hash(data_hash: { classification_tree_label => [classification_id] }, current_user: user, partial_update: true, prevent_history: true)

          return unless respond_to?(:children)

          children&.each do |child|
            child.set_data_hash(data_hash: { classification_tree_label => [classification_id] }, current_user: user, partial_update: true, prevent_history: true) if child.life_cycle_classification?(classification_id)
          end
        end
      end
    end
  end
end
