module DataCycleCore
  class ClassificationsTreesLabel < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    has_many :classifications_trees

  end
end
