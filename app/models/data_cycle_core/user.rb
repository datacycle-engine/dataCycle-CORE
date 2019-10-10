# frozen_string_literal: true

module DataCycleCore
  class User < ApplicationRecord
    include Content::ExternalData

    devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :lockable
    devise :omniauthable, omniauth_providers: Devise.omniauth_configs.keys if Devise.try(:omniauth_configs).present?

    attr_accessor :raw_password, :skip_callbacks

    has_many :stored_filters, dependent: :destroy
    has_many :watch_lists, dependent: :destroy
    has_many :subscriptions, dependent: :destroy
    has_many :things_subscribed, through: :subscriptions, source: :subscribable, source_type: 'DataCycleCore::Thing'
    belongs_to :role

    has_many :things_created, class_name: 'DataCycleCore::Thing', foreign_key: :created_by
    has_many :things_updated, class_name: 'DataCycleCore::Thing', foreign_key: :updated_by
    has_many :things_deleted, class_name: 'DataCycleCore::Thing', foreign_key: :deleted_by
    has_many :represented_by, class_name: 'DataCycleCore::Thing', foreign_key: :representation_of_id
    has_many :thing_histories_created, class_name: 'DataCycleCore::Thing::History', foreign_key: :created_by
    has_many :thing_histories_updated, class_name: 'DataCycleCore::Thing::History', foreign_key: :updated_by
    has_many :thing_histories_deleted, class_name: 'DataCycleCore::Thing::History', foreign_key: :deleted_by
    has_many :histories_represented_by, class_name: 'DataCycleCore::Thing::History', foreign_key: :representation_of_id

    has_many :user_group_users, dependent: :destroy
    has_many :user_groups, through: :user_group_users

    has_many :received_data_links, class_name: :DataLink, foreign_key: :receiver_id, dependent: :destroy
    has_many :created_data_links, class_name: :DataLink, foreign_key: :creator_id, dependent: :destroy

    has_many :assets, foreign_key: :creator_id, class_name: 'DataCycleCore::Asset'

    has_many :watch_list_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :shared_watch_lists, through: :watch_list_shares, source: :watch_list

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable
    has_many :external_systems, through: :external_system_syncs

    has_many :activities, dependent: :destroy
    belongs_to :creator, class_name: 'DataCycleCore::User'
    has_many :created_users, class_name: 'DataCycleCore::User', foreign_key: :creator_id

    before_create :set_default_role

    delegate :can?, :cannot?, to: :ability

    after_create :execute_create_webhooks, unless: :skip_callbacks
    after_update_commit :execute_update_webhooks, if: proc { |u| !u.skip_callbacks && (u.saved_changes.keys & ['access_token', 'email', 'encrypted_password', 'external', 'family_name', 'given_name', 'name', 'notification_frequency', 'provider', 'role_id']).present? }
    after_destroy :execute_delete_webhooks, unless: :skip_callbacks

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
      new_user.skip_callbacks = true
      new_user.save
      new_user
    end

    def update_with_token(token)
      if token.dig(:user, :rank).present?
        rank = DataCycleCore.features.dig(:user_api, :allowed_ranks)&.include?(token.dig(:user, :rank).to_i) ? token.dig(:user, :rank).to_i : DataCycleCore.features.dig(:user_api, :default_rank).to_i
      end

      user_keys = DataCycleCore.features.dig(:user_api, :user_params).deep_transform_keys { |k| k.camelize(:lower) }
      authorized_attributes = Array(user_keys.select { |_, v| v.nil? }.keys)
      authorized_attributes.concat(Array(user_keys.compact.keys.map { |k| "#{k}Ids" }))

      self.attributes = token.dig(:user).slice(*authorized_attributes).deep_transform_keys(&:underscore).merge(rank.present? ? { role: DataCycleCore::Role.find_by(rank: rank) } : {})
      save
      self
    end

    def self.find_with_token(token)
      if token[:iss] == DataCycleCore::JsonWebToken::ISSUER && token[:jti].present?
        User.find_by(id: token[:user_id], jti: token[:jti])
      elsif token[:token].present?
        User.find_by(access_token: token[:token])
      elsif token[:user_id].present?
        User.find_by(id: token[:user_id])
      elsif token[:user].present? && token.dig(:user, :email).present? && DataCycleCore.features.dig(:user_api, :enabled)
        User.find_or_initialize_by(email: token.dig(:user, :email)).update_with_token(token)
      end
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
      Webhook::Update.execute_all(self)
    end

    def execute_delete_webhooks
      Webhook::Delete.execute_all(self)
    end
  end
end
