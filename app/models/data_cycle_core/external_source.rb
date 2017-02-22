module DataCycleCore
  class ExternalSource < ActiveRecord::Base
    has_many :places
    has_many :classifications_regions
  end
end
