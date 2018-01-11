module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord
    acts_as_paranoid

    belongs_to :external_source

    has_many :classification_trees, dependent: :destroy
    has_many :classification_aliases, through: :classification_trees, source: :sub_classification_alias

    def ancestors
      []
    end
  end
end
