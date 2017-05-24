module DataCycleCore
  class Classification < ApplicationRecord

    include DataSetter

    belongs_to :external_sources

    has_many :classification_places
    has_many :places, through: :classification_places

    has_many :classification_creative_works
    has_many :creative_works, through: :classification_creative_works

    has_many :classification_groups
    has_many :classification_aliases, through: :classification_groups
  end
end
