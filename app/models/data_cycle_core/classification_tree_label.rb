module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    has_many :classification_trees

  end
end
