module DataCycleCore
  class User < ApplicationRecord
    devise :database_authenticatable, :registerable,
           :recoverable, :rememberable, :trackable, :validatable, :lockable

    has_many :use_cases
    has_many :stored_filters, dependent: :destroy
    has_many :watch_lists, dependent: :destroy
    has_many :subscriptions, dependent: :destroy
    belongs_to :role

    has_many :content_content_a, class_name: 'DataCycleCore::ContentContent', as: :content_a, dependent: :destroy
    has_many :content_content_b, class_name: 'DataCycleCore::ContentContent', as: :content_b, dependent: :destroy
    has_many :content_content_a_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_a_history, dependent: :destroy
    has_many :content_content_b_history, class_name: 'DataCycleCore::ContentContent::History', as: :content_b_history, dependent: :destroy

    has_many :user_group_users, dependent: :destroy
    has_many :user_groups, through: :user_group_users

    has_many :received_data_links, class_name: :DataLink, foreign_key: :receiver_id, dependent: :destroy
    has_many :created_data_links, class_name: :DataLink, foreign_key: :creator_id, dependent: :destroy

    before_create :set_default_role

    include UserHelpers

    def admin?
      admin
    end

    def has_rank?(rank)
      self&.role&.rank&.>= rank
    end

    def is_rank?(rank)
      self&.role&.rank == rank
    end

    def has_user_group?(group_name)
      self&.user_groups&.map(&:name)&.include?(group_name)
    end

    def send_notification(contents)
      return unless contents.size.positive?

      SubscriptionMailer.notify(self, contents).deliver_later
    end

    private

    def set_default_role
      self.role ||= DataCycleCore::Role.find_by(name: 'standard')
    end
  end
end
