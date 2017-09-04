module DataCycleCore
  class ClassificationTreeLabel < ApplicationRecord

    include DataSetter

    belongs_to :external_source

    has_many :classification_trees, dependent: :destroy
  end
end
