# frozen_string_literal: true

module DataCycleCore
  class User < ApplicationRecord
    include Content::ExternalData
    include DataCycleCore::UserExtensions::Filters

    devise :database_authenticatable, :recoverable, :rememberable, :trackable, :validatable, :lockable, :omniauthable, omniauth_providers: Devise.omniauth_configs.keys
    devise :registerable if Feature::UserRegistration.enabled?
    devise :confirmable if Feature::UserConfirmation.enabled?

    WEBHOOK_ACCESSORS = [:raw_password, :mailer_layout, :viewer_layout, :redirect_url].freeze

    attr_accessor :skip_callbacks, :template_namespaces, :issuer, :forward_to_url, :synchronous_webhooks, :webhook_source, *WEBHOOK_ACCESSORS
    attr_writer :user_api_feature, :ability
    WEBHOOKS_ATTRIBUTES = [
      'access_token',
      'email',
      'encrypted_password',
      'external',
      'family_name',
      'given_name',
      'name',
      'notification_frequency',
      'providers',
      'role_id',
      'default_locale'
    ].freeze

    Devise.omniauth_configs.each_key do |provider|
      store_accessor :providers, provider.to_sym, suffix: 'uid'
    end

    has_many :stored_filters, dependent: :destroy
    has_many :watch_lists, dependent: :destroy
    has_one :my_selection, -> { where(my_selection: true) }, class_name: 'DataCycleCore::WatchList'
    has_many :api_accessible_watch_lists, ->(user) { unscope(where: :user_id).accessible_by(user.send(:ability)).without_my_selection }, class_name: 'DataCycleCore::WatchList'
    has_many :api_accessible_stored_filters, ->(user) { unscope(where: :user_id).accessible_by(user.send(:ability), :api).named }, class_name: 'DataCycleCore::StoredFilter'
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
    has_many :valid_received_data_links, -> { valid }, class_name: :DataLink, foreign_key: :receiver_id
    has_many :valid_received_readable_data_links, -> { valid.readable }, class_name: :DataLink, foreign_key: :receiver_id
    has_many :valid_received_writable_data_links, -> { valid.writable }, class_name: :DataLink, foreign_key: :receiver_id
    has_many :valid_received_readable_stored_filter_data_links, -> { valid.readable.joins(:collection).where(collection: { type: 'DataCycleCore::StoredFilter' }) }, class_name: :DataLink, foreign_key: :receiver_id

    has_many :assets, foreign_key: :creator_id, class_name: 'DataCycleCore::Asset'

    has_many :collection_shares, as: :shareable, dependent: :destroy, inverse_of: :shareable
    has_many :shared_collections, through: :collection_shares, source: :watch_list

    has_many :external_system_syncs, as: :syncable, dependent: :destroy, inverse_of: :syncable
    has_many :external_systems, through: :external_system_syncs

    has_many :activities, dependent: :destroy
    belongs_to :creator, class_name: 'DataCycleCore::User'
    has_many :created_users, class_name: 'DataCycleCore::User', foreign_key: :creator_id

    before_save :reset_ui_locale, unless: :ui_locale_allowed?
    before_create :set_default_role

    delegate :can?, :cannot?, :can_attribute?, to: :ability

    after_create :execute_create_webhooks, unless: :skip_callbacks
    after_update_commit :execute_update_webhooks, if: lambda { |u|
      !u.skip_callbacks &&
        u.saved_changes.keys.intersect?(u.allowed_webhook_attributes)
    }
    after_destroy :execute_delete_webhooks, unless: :skip_callbacks

    default_scope { where(deleted_at: nil) }

    CONTROLLER_CONTEXT_SCHEMA = Dry::Schema.Params do
      optional(:controller).filled(:string)
      optional(:action).filled(:string)
    end

    CUSTOM_TRACKING_HEADERS = {
      middlewareOrigin: 'X-Dc-Middleware-Origin',
      widgetIdentifier: 'X-Dc-Widget-Identifier',
      widgetType: 'X-Dc-Widget-Type',
      widgetVersion: 'X-Dc-Widget-Version'
    }.freeze

    def additional_webhook_attributes
      Devise.omniauth_configs.keys.map { |k| "#{k}_uid" } + ['providers']
    end

    def user_api_feature
      @user_api_feature ||= DataCycleCore::Feature::UserApi.new(nil, self)
    end

    def mailer_from
      user_api_feature.user_mailer_from
    end

    def recoverable?
      !(external? || is_rank?(0))
    end

    def forward_to_url_with_token(tokens)
      return if forward_to_url.blank?

      uri = Addressable::URI.parse(forward_to_url.to_s)
      uri.query = ([uri.query] + tokens.map { |k, v| "#{k.to_s.camelize(:lower)}=#{v}" }).compact.join('&') if tokens.present?

      uri.to_s
    end

    def allowed_webhook_attributes
      WEBHOOKS_ATTRIBUTES
    end

    def concatenated_name
      organization? ? name : "#{given_name} #{family_name}".squish.presence
    end

    def full_name
      concatenated_name || '__unnamed_user__'
    end

    def full_name_or_email
      concatenated_name || email
    end

    def full_name_with_email
      concatenated_name ? "#{concatenated_name} <#{email}>" : email
    end

    def default_filter(filters = [], _scope = 'backend', _template_name = nil)
      filters
    end

    def has_rank?(rank)
      role&.rank&.>= rank
    end

    def is_rank?(rank)
      role&.rank == rank
    end

    def is_role?(*role_names)
      role&.name&.in?(Array.wrap(role_names).map(&:to_s))
    end

    def has_user_group?(group_name)
      user_groups.any? { |ug| ug.name == group_name }
    end

    def has_user_group_permission?(permission_key)
      user_groups_by_permission(permission_key).exists?
    end

    def user_groups_by_permission(permission_key)
      user_groups.user_groups_with_permission(permission_key)
    end

    def locked?
      locked_at.present?
    end

    def organization?
      name.present? && given_name.blank? && family_name.blank?
    end

    def include_groups_user_ids
      user_groups.map { |ug| ug.users.pluck(:id) }.flatten.uniq << id
    end

    def send_notification(content_ids)
      return if content_ids.blank?

      DataCycleCore::SubscriptionMailer.notify(self, content_ids).deliver_later
    end

    def generate_user_token(refresh_jti = false)
      update_columns(jti: SecureRandom.uuid) if refresh_jti || jti.blank?

      DataCycleCore::JsonWebToken.encode(payload: { user_id: id, jti:, original_iss: user_api_feature.current_issuer }.compact_blank)
    end

    def update_with_token(token)
      self.role = user_api_feature.allowed_role(token.dig(:user, :rank)) if user_api_feature.rank_allowed?(token.dig(:user, :rank))
      self.attributes = user_api_feature.parsed_user_params(ActionController::Parameters.new(token[:user] || {}))

      save

      self
    end

    def self.find_with_token(token)
      if token[:iss] == DataCycleCore::Feature::UserApi.issuer && token[:jti].present?
        User.find_by(id: token[:user_id], jti: token[:jti])
      elsif token[:token].present?
        User.find_by(access_token: token[:token])
      elsif token[:user_id].present?
        User.find_by(id: token[:user_id])
      elsif token[:external_user_id].present?
        User.find_by(uid: token[:external_user_id])
      elsif token[:user].present? && token.dig(:user, :email).present? && DataCycleCore::Feature::UserApi.enabled?
        User.find_or_initialize_by(email: token.dig(:user, :email).downcase).update_with_token(token)
      end
    end

    def self.find_by_provider_uid(provider, uid)
      return if provider.blank? || uid.blank?

      find_by('users.providers @> ?', { provider => uid }.to_json)
    end

    def self.find_by_omniauth(auth, case_sensitive = false)
      return if auth&.info&.email.blank?

      email = case_sensitive ? auth.info.email : auth.info.email.downcase
      find_by_provider_uid(auth.provider, auth.uid) || find_by(email:)
    end

    def self.find_or_initialize_by_omniauth(auth, case_sensitive = false)
      return if auth&.info&.email.blank?

      email = case_sensitive ? auth.info.email : auth.info.email.downcase
      user = find_by_omniauth(auth, case_sensitive) || new(email:)
      user.send(:"#{auth.provider}_uid=", auth.uid)

      user
    end

    def self.from_omniauth(auth)
      return if auth&.info&.email.blank?

      user = find_or_initialize_by_omniauth(auth)

      if user.new_record?
        user.password = Devise.friendly_token
        user.raw_password = user.password
        user.given_name = auth.info.first_name
        user.family_name = auth.info.last_name
        user.role = DataCycleCore::Role.find_by(name: Devise.omniauth_configs[auth.provider.to_sym].options[:default_role]) if Devise.omniauth_configs[auth.provider.to_sym]&.options&.[](:default_role).present?
        user.confirmed_at = Time.zone.now if DataCycleCore::Feature::UserRegistration.enabled? && user.confirmed_at.blank?
        user.external = true
      end

      user.save!
      user
    end

    def as_user_api_json
      as_json(user_api_feature.json_params)
        .merge(as_json(only: [:additional_attributes]).tap { |u| u['additional_attributes']&.slice!(*user_api_feature.json_additional_attributes) })
        .deep_transform_keys { |k| k.to_s.camelize(:lower) }
    end

    def self.as_user_api_json
      all.map(&:as_user_api_json)
    end

    def to_select_option(locale = DataCycleCore.ui_locales.first, disable_locked = true)
      DataCycleCore::Filter::SelectOption.new(
        id:,
        name: ActionController::Base.helpers.safe_join([
          ActionController::Base.helpers.tag.i(class: 'fa dc-type-icon user-icon'),
          email
        ].compact, ' '),
        html_class: model_name.param_key,
        dc_tooltip: ActionController::Base.helpers.safe_join(
          [
            "#{model_name.human(count: 1, locale:)}:",
            full_name_with_status(locale:)
          ], ' '
        ),
        disabled: disable_locked && locked?,
        class_key: model_name.param_key
      )
    end

    def self.to_select_options(locale = DataCycleCore.ui_locales.first, disable_locked = true)
      all.map { |v| v.to_select_option(locale, disable_locked) }
    end

    def full_name_with_status(locale: DataCycleCore.ui_locales.first)
      return full_name unless locked? || deleted?

      ActionController::Base.helpers.safe_join([
        full_name,
        ActionController::Base.helpers.tag.span(
          ActionController::Base.helpers.safe_join(
            [
              ActionController::Base.helpers.tag.i(class: 'fa fa-ban'),
              self.class.human_attribute_name(deleted? ? :deleted_at : :locked_at, locale:)
            ],
            ' '
          ),
          class: 'alert-color'
        )
      ].compact, ' ')
    end

    def log_request_activity(type:, data: {}, request: nil, activitiable: nil)
      data ||= {}
      data.deep_stringify_keys!
      data.merge!(CONTROLLER_CONTEXT_SCHEMA.call(request&.params).to_h.deep_stringify_keys)
      data['format'] = request&.format&.to_s
      data['referer'] = request&.referer&.to_s
      data['origin'] = request&.origin&.to_s

      CUSTOM_TRACKING_HEADERS.each do |key, header|
        data[key.to_s] = request&.headers&.[](header)&.to_s
      end

      transaction(joinable: true) do
        activities.create(activity_type: type, data:, activitiable:)
      end
    end

    alias log_activity log_request_activity

    def deleted?
      deleted_at.present?
    end

    def self.with_deleted
      unscope(where: :deleted_at)
    end

    def destroy
      attributes_hash = self.class.column_names.except(['id', 'email', 'encrypted_password', 'created_at', 'role_id', 'type', 'creator_id']).to_h { |v| [v.to_sym, nil] }

      attributes_hash.merge!({
        email: "u#{id}@ano.nym",
        given_name: '',
        family_name: "anonym_#{id.first(8)}",
        password: SecureRandom.hex(10),
        default_locale: I18n.default_locale,
        ui_locale: I18n.default_locale,
        updated_at: Time.zone.now,
        locked_at: Time.zone.now,
        sign_in_count: 0,
        external: false,
        deleted_at: Time.zone.now,
        subscription_ids: nil,
        providers: {}
      })

      skip_confirmation_notification! if respond_to?(:skip_confirmation_notification!)
      skip_reconfirmation! if respond_to?(:skip_reconfirmation!)

      update(attributes_hash)
    end

    def reload(options = nil)
      remove_instance_variable(:@ability) if instance_variable_defined?(:@ability)

      super
    end

    def icon_class
      organization? ? 'organization' : 'user'
    end

    private

    def set_default_role
      self.role ||= DataCycleCore::Feature::UserRegistration.default_role
    end

    def ui_locale_allowed?
      ui_locale.blank? || DataCycleCore.ui_locales.map(&:to_s).include?(ui_locale.to_s)
    end

    def reset_ui_locale
      self.ui_locale = self.class.column_defaults['ui_locale']
    end

    def ability
      return @ability if defined? @ability

      @ability = DataCycleCore::Ability.new(self)
    end

    def execute_update_webhooks
      DataCycleCore::Webhook::Update.execute_all(self)
    end

    def execute_create_webhooks
      DataCycleCore::Webhook::Create.execute_all(self)
    end

    def execute_delete_webhooks
      DataCycleCore::Webhook::Delete.execute_all(self)
    end
  end
end
