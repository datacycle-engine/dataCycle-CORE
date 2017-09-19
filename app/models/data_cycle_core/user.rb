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

    before_create :set_default_role

    include UserHelpers

    def admin?
      self.admin
    end

    def has_rank?(rank)
      self.role.rank >= rank
    end

    private
    def set_default_role
      self.role ||= DataCycleCore::Role.find_by(label: 'user')
    end
  end
end
