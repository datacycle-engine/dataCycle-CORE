# frozen_string_literal: true

module DataCycleCore
  class User < ApplicationRecord
    include Content::ExternalData

    devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :lockable, :omniauthable, omniauth_providers: Devise.omniauth_configs.keys
    devise :registerable, :confirmable if DataCycleCore::Feature::UserRegistration.enabled?

    WEBHOOK_ACCESSORS = [:raw_password, :synchronous_webhooks, :mailer_layout, :viewer_layout, :redirect_url].freeze

    attr_accessor :skip_callbacks, *WEBHOOK_ACCESSORS

    WEBHOOKS_ATTRIBUTES = [
      'access_token',
      'email',
      'encrypted_password',
      'external',
      'family_name',
      'given_name',
      'name',
      'notification_frequency',
      'provider',
      'role_id',
      'default_locale'
    ].freeze

    has_many :stored_filters, dependent: :destroy
    has_many :watch_lists, dependent: :destroy
    has_one :my_selection, -> { where(my_selection: true) }, class_name: 'DataCycleCore::WatchList'
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
    after_update_commit :execute_update_webhooks, if: proc { |u| !u.skip_callbacks && (u.saved_changes.keys & u.allowed_webhook_attributes).present? }
    after_destroy :execute_delete_webhooks, unless: :skip_callbacks

    def recoverable?
      !(external? || is_rank?(0))
    end

    def allowed_webhook_attributes
      WEBHOOKS_ATTRIBUTES
    end

    def full_name
      (name || "#{given_name} #{family_name}".presence || '__unnamed_user__').squish
    end

    def default_filter(filters = [], _scope = 'backend', _template_name = nil)
      filters
    end

    def has_rank?(rank)
      self&.role&.rank&.>= rank
    end

    def is_rank?(rank)
      self&.role&.rank == rank
    end

    def is_role?(*role_names)
      role&.name&.in?(Array.wrap(role_names).map(&:to_s))
    end

    def has_user_group?(group_name)
      user_groups.exists?(name: group_name)
    end

    def include_groups_user_ids
      user_groups.map { |ug| ug.users.ids }.flatten.uniq << id
    end

    def send_notification(contents)
      return unless contents.size.positive?

      SubscriptionMailer.notify(self, contents).deliver_later
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
      elsif token[:external_user_id].present?
        User.find_by(uid: token[:external_user_id])
      elsif token[:user].present? && token.dig(:user, :email).present? && DataCycleCore.features.dig(:user_api, :enabled)
        User.find_or_initialize_by(email: token.dig(:user, :email)).update_with_token(token)
      end
    end

    def self.from_omniauth(auth)
      return if auth&.info&.email.blank?

      new_user = find_or_initialize_by(email: auth.info.email) do |user|
        user.email = auth.info.email
        user.password = Devise.friendly_token[0, 20]
        user.given_name = auth.info.first_name
        user.family_name = auth.info.last_name
        user.role = DataCycleCore::Role.find_by(name: Devise.omniauth_configs[auth.provider.to_sym].options[:default_role]) if Devise.omniauth_configs[auth.provider.to_sym]&.options&.[](:default_role).present?
      end

      if new_user.provider.blank? && new_user.uid.blank?
        new_user.provider = auth.provider
        new_user.uid = auth.uid
      end

      new_user.confirmed_at = Time.zone.now if DataCycleCore::Feature::UserRegistration.enabled? && new_user.confirmed_at.blank?
      new_user.external = true
      new_user.additional_attributes ||= {}
      new_user.additional_attributes[auth.provider] = {
        info: auth.info,
        raw_info: auth.dig('extra', 'raw_info')
      }

      new_user.save!
      new_user
    end

    def as_user_api_json
      as_json(
        only: Array(DataCycleCore.features.dig(:user_api, :user_params).select { |_, v| v.nil? }.keys) + [:id],
        include: {
          role: {
            only: [:name, :rank]
          }
        }.merge(DataCycleCore.features.dig(:user_api, :user_params)&.compact&.map { |k, v| [k.pluralize, v.is_a?(Array) ? { only: v } : {}] }.to_h)
      )
    end

    private

    def set_default_role
      self.role ||= DataCycleCore::Feature::UserRegistration.default_role
    end

    def ability
      return @ability if defined? @ability

      @ability = DataCycleCore::Ability.new(self)
    end

    def execute_update_webhooks
      if synchronous_webhooks
        DataCycleCore::Webhook::Update.execute_all(self)
      else
        DataCycleCore::WebhooksJob.perform_later(
          id,
          self.class.name,
          'update',
          WEBHOOK_ACCESSORS.index_with { |a| try(a) }.compact
        )
      end
    end

    def execute_create_webhooks
      if synchronous_webhooks
        DataCycleCore::Webhook::Create.execute_all(self)
      else
        DataCycleCore::WebhooksJob.perform_later(
          id,
          self.class.name,
          'create',
          WEBHOOK_ACCESSORS.index_with { |a| try(a) }.compact
        )
      end
    end

    def execute_delete_webhooks
      DataCycleCore::Webhook::Delete.execute_all(self)
    end
  end
end
