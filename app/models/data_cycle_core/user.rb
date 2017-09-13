module DataCycleCore
  class User < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable and :omniauthable
    #:saml_authenticatable, :trackable
     devise :database_authenticatable, :registerable,
            :recoverable, :rememberable, :trackable, :validatable

    has_many :use_cases
    has_many :watch_lists, dependent: :destroy
    has_many :subscriptions, dependent: :destroy

    def admin?
      self.admin
    end

  end
end
