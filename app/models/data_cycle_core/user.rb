module DataCycleCore
  class User < ApplicationRecord
    # Include default devise modules. Others available are:
    # :confirmable, :lockable, :timeoutable and :omniauthable
    devise :saml_authenticatable, :trackable
    # :database_authenticatable, :registerable,
    #        :recoverable, :rememberable, :trackable, :validatable

    has_many :use_cases

    def admin?
      self.admin
    end

  end
end
