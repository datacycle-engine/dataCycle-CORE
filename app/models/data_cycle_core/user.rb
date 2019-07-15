# frozen_string_literal: true

module DataCycleCore
  class User < ApplicationRecord
    include Content::ExternalData

    devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :lockable, :omniauthable, omniauth_providers: [:openid_connect]

    attr_accessor :raw_password, :skip_callbacks

    has_many :stored_filters, dependent: :destroy
    has_many :watch_lists, dependent: :destroy
    has_many :subscriptions, dependent: :destroy
    belongs_to :role

    has_many :things_created, class_name: 'DataCycleCore::Thing', foreign_key: :created_by
    has_many :things_updated, class_name: 'DataCycleCore::Thing', foreign_key: :updated_by
    has_many :things_deleted, class_name: 'DataCycleCore::Thing', foreign_key: :deleted_by
    has_many :thing_histories_created, class_name: 'DataCycleCore::Thing::History', foreign_key: :created_by
    has_many :thing_histories_updated, class_name: 'DataCycleCore::Thing::History', foreign_key: :updated_by
    has_many :thing_histories_deleted, class_name: 'DataCycleCore::Thing::History', foreign_key: :deleted_by

    has_many :user_group_users, dependent: :destroy
    has_many :user_groups, through: :user_group_users

    has_many :received_data_links, class_name: :DataLink, foreign_key: :receiver_id, dependent: :destroy
    has_many :created_data_links, class_name: :DataLink, foreign_key: :creator_id, dependent: :destroy

    has_many :assets, foreign_key: :creator_id, class_name: 'DataCycleCore::Asset'

    has_many :watch_list_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :shared_watch_lists, through: :watch_list_shares, source: :watch_list

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable
    has_many :external_systems, through: :external_system_syncs

    before_create :set_default_role

    delegate :can?, :cannot?, to: :ability

    after_create_commit :execute_create_webhooks, unless: :skip_callbacks
    after_update_commit :execute_update_webhooks, unless: :skip_callbacks
    after_destroy_commit :execute_delete_webhooks, unless: :skip_callbacks

    def recoverable?
      !(external? || is_rank?(0))
    end

    def full_name
      (name || "#{given_name} #{family_name}".presence || '__unnamed_user__').squish
    end

    def default_filter(filters = [])
      filters
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

    def include_groups_user_ids
      user_groups.map { |ug| ug.users.ids }.flatten.uniq << id
    end

    def send_notification(contents)
      return unless contents.size.positive?

      SubscriptionMailer.notify(self, contents).deliver_later
    end

    def self.from_omniauth(auth)
      return if auth&.info&.email.blank?

      new_user = find_or_initialize_by(email: auth.info.email) do |user|
        user.password = Devise.friendly_token
      end
      new_user.provider = auth.provider
      new_user.uid = auth.uid
      new_user.external = true
      new_user.save
      new_user
    end

    private

    def set_default_role
      self.role ||= DataCycleCore::Role.find_by(name: 'standard')
    end

    def ability
      @ability ||= DataCycleCore::Ability.new(self)
    end

    def execute_create_webhooks
      Webhook::Create.execute_all(self)
    end

    def execute_update_webhooks
      binding.pry
      Webhook::Update.execute_all(self)
    end

    def execute_delete_webhooks
      Webhook::Delete.execute_all(self)
    end
  end
end
