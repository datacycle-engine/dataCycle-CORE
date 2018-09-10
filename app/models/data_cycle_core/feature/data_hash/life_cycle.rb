# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module LifeCycle
        def set_life_cycle_classification(classification_tree_label, classification_id, user)
          set_data_hash_attribute(classification_tree_label, [classification_id], user)

          return unless respond_to?(:children)

          children&.each do |child|
            child.set_data_hash_attribute(classification_tree_label, [classification_id], user) if DataCycleCore::Feature::LifeCycle.ordered_classifications(child)&.values&.map { |value| value[:id] }&.include?(classification_id)
          end
        end
      end
    end
  end
end
