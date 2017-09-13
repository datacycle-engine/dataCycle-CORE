module DataCycleCore
  class ClassificationGroup < ApplicationRecord

    include DataSetter

    after_destroy ->() { DataCycleCore::Classification.left_outer_joins(:classification_groups).where(classification_groups: {id: nil}).destroy_all }

    acts_as_paranoid

    belongs_to :external_source
    belongs_to :classification
    belongs_to :classification_alias
  end
end
