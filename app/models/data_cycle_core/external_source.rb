module DataCycleCore
  class ExternalSource < ApplicationRecord
    has_many :places
    has_many :classifications_regions
  end
end
