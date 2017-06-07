module DataCycleCore
  class ExternalSource < ApplicationRecord
    has_many :places
    has_many :classifications_regions

    has_many :use_cases
  end
end
