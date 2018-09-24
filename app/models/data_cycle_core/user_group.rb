# frozen_string_literal: true

module DataCycleCore
  class UserGroup < ApplicationRecord
    validates :name, presence: true

    has_many :user_group_users, dependent: :destroy
    has_many :users, through: :user_group_users

    has_many :watch_list_user_groups, dependent: :destroy
    has_many :watch_lists, through: :watch_list_user_groups
  end
end
