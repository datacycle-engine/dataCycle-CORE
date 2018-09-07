# frozen_string_literal: true

module DataCycleCore
  class Role < ApplicationRecord
    has_many :users

    def self.ranks_lte(rank)
      where('rank <= ?', rank).order(rank: :desc).pluck(:rank)
    end
  end
end
