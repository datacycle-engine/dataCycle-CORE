# frozen_string_literal: true

module DataCycleCore
  class UserGroupUser < ApplicationRecord
    belongs_to :user
    belongs_to :user_group, touch: true
  end
end
