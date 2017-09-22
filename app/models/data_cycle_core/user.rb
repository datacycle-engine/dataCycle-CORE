module DataCycleCore
  class User < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable and :omniauthable
    #:saml_authenticatable, :trackable
     devise :database_authenticatable, :registerable,
            :recoverable, :rememberable, :trackable, :validatable, :lockable

    has_many :use_cases
    has_many :watch_lists, dependent: :destroy
    has_many :subscriptions, dependent: :destroy
    belongs_to :role

    has_many :user_group_users, dependent: :destroy
    has_many :user_groups, through: :user_group_users

    before_create :set_default_role

    include UserHelpers

    def admin?
      self.admin
    end

    def has_rank?(rank)
      self.role && self.role.rank >= rank
    end

    private
    def set_default_role
      self.role ||= DataCycleCore::Role.find_by(name: 'standard')
    end
  end
end
