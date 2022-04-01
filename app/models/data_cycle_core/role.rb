# frozen_string_literal: true

module DataCycleCore
  class Role < ApplicationRecord
    has_many :users, dependent: :nullify
  end
end
