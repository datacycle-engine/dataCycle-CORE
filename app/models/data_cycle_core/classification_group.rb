# frozen_string_literal: true

module DataCycleCore
  class ClassificationGroup < ApplicationRecord
    class PrimaryClassificationGroup < ApplicationRecord
      self.table_name = 'primary_classification_groups'

      acts_as_paranoid

      belongs_to :external_source
      belongs_to :classification
      belongs_to :classification_alias

      def readonly?
        true
      end
    end

    after_destroy -> { DataCycleCore::Classification.left_outer_joins(:classification_groups).where(classification_groups: { id: nil }).destroy_all }

    acts_as_paranoid

    belongs_to :external_source
    belongs_to :classification
    belongs_to :classification_alias
  end
end
