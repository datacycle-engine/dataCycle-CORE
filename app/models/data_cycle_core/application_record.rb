# frozen_string_literal: true

module DataCycleCore
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    include Common::ByOrderedValues
  end
end
