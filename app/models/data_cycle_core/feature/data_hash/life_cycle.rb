# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module LifeCycle
        def set_life_cycle_classification(key, classification_id, user)
          valid = set_data_hash(data_hash: { key => [classification_id] }, current_user: user, partial_update: true)

          return valid unless respond_to?(:children)

          children&.each do |child|
            child.set_data_hash(data_hash: { key => [classification_id] }, current_user: user, partial_update: true) if child.life_cycle_classification?(classification_id)
          end
          valid
        end
      end
    end
  end
end
