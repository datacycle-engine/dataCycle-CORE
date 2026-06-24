# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserApi < Base
      attr_reader :current_issuer
      attr_accessor :user

      def initialize(current_issuer = nil, user = nil)
        self.user = user
        self.current_issuer = current_issuer
      end

      def current_issuer=(iss)
        @current_issuer = iss.to_s unless self.class.secret_for_issuer(iss).nil?
      end

      def configuration
        return @configuration if defined? @configuration

        @configuration = self.class.configuration
          .except(:allowed_issuers, :public_keys)
          .merge(current_issuer.nil? ? {} : self.class.configuration.dig(:allowed_issuers, current_issuer)&.except(:public_key) || {})
      end

      def user_params
        configuration[:user_params] || {}
      end

      def hash_to_allowed_params(hash)
        hash.map do |k, v|
          if DataCycleCore::User.reflect_on_all_associations(:has_many).map(&:name).include?(k.to_sym)
            { "#{DataCycleCore::User.reflections[k.to_s].klass.name.demodulize.camelize(:lower)}Ids" => [] }
          elsif v.is_a?(::Hash)
            { k.camelize(:lower).to_sym => hash_to_allowed_params(v) }
          else
            k.camelize(:lower).to_sym
          end
        end
      end

      def allowed_user_params
        hash_to_allowed_params(user_params)
      end

      def parsed_user_params(params)
        params
          .permit(allowed_user_params).to_h
          .deep_transform_keys(&:underscore)
          .with_indifferent_access
      end

      # checks a caller-supplied forwardToUrl/redirectUrl against the allowlist
      # for this feature. The current issuer's config, when present, replaces the
      # global :allowed_redirect_hosts (see #configuration).
      def allowed_redirect_url?(url)
        self.class.url_allowed?(url, configuration[:allowed_redirect_hosts])
      end

      def default_rank
        configuration[:default_rank].to_i
      end

      def rank_allowed?(rank)
        rank.present? && Array.wrap(configuration[:allowed_ranks]).include?(rank.to_i)
      end

      def role_by_rank(rank)
        DataCycleCore::Role.find_by(rank: rank.to_i)
      end

      def allowed_role(rank)
        role_by_rank(rank_allowed?(rank) ? rank : default_rank)
      end

      def allowed_role!(rank)
        return role_by_rank(rank) if rank_allowed?(rank)

        raise DataCycleCore::Error::Api::UserApiRankError, 'RANK_NOT_ALLOWED' if rank.present?

        role_by_rank(default_rank)
      end

      def default_user_groups
        return [] if configuration[:default_user_groups].blank?

        DataCycleCore::UserGroup.where(name: configuration[:default_user_groups])
      end

      def new_user_notification?
        configuration[:new_user_notification].present?
      end

      def users_to_notify
        emails = []

        emails.concat(DataCycleCore::UserGroup.find_by(name: configuration.dig(:new_user_notification, :user_group))&.users&.pluck(:email) || []) if configuration.dig(:new_user_notification, :user_group).present?

        emails.concat(Array.wrap(configuration.dig(:new_user_notification, :email)))

        emails.compact
      end

      def notify_users
        DataCycleCore::UserApiMailer.notify(users_to_notify, user, { issuer: current_issuer, template_namespaces: [current_issuer] }).deliver_later
      end

      def notify_confirmed_user
        DataCycleCore::UserApiMailer.notify_confirmed(user, { issuer: current_issuer, template_namespaces: [current_issuer] }).deliver_later
      end

      def user_mailer_from
        configuration.dig(:user_mailer, :from).presence || Rails.configuration.action_mailer.default_options&.dig(:from)
      end

      def user_mailer_logo
        configuration.dig(:user_mailer, :logo).presence
      end

      def user_mailer_customercolor
        configuration.dig(:user_mailer, :customercolor).presence
      end

      def user_confirmed_for_api?
        configuration.dig(:new_user_confirmation, :user_group)&.then { |g| user&.has_user_group?(g) } || false
      end

      def json_additional_attributes
        (user_params['additional_attributes'] || {}).keys
      end

      def additional_tile_values(user)
        return unless self.class.enabled?

        tile_attributes = {}

        configuration[:additional_tile_attributes]&.each do |key, value|
          column = DataCycleCore::User.columns.find { |c| c.name == key }

          if column.type == :jsonb
            tile_attributes.merge!(user.try(key)&.slice(*value.keys)&.transform_keys { |k| "#{key}/#{k}" } || {})
          else
            tile_attributes[key] = user.try(key)
          end
        end

        tile_attributes.reject { |_k, v| DataCycleCore::DataHashService.blank?(v) }
      end

      def json_params
        {
          only: user_params.filter { |k, v| DataCycleCore::User.reflect_on_all_associations(:has_many).map(&:name).exclude?(k.to_sym) && v.nil? }.keys + [:id],
          include: {
            role: {
              only: [:name, :rank]
            }
          }.merge(
            user_params
              .filter { |k, _| DataCycleCore::User.reflect_on_all_associations(:has_many).map(&:name).include?(k.to_sym) }
              .to_h do |k, v|
                if v.is_a?(::Array)
                  [k.to_sym, { only: v }]
                elsif v.is_a?(::Hash)
                  [k.to_sym, { only: v.keys }]
                else
                  [k.to_sym, {}]
                end
              end
          )
        }
      end

      class << self
        # global-only allowlist check (no issuer context, e.g. PasswordsController web flow)
        def redirect_url_allowed?(url)
          url_allowed?(url, configuration[:allowed_redirect_hosts])
        end

        # returns true when +url+ is a first-party (relative) URL or its host
        # matches one of the configured +patterns+. Fails closed: an absolute URL
        # with no matching pattern (or an empty/blank pattern list) is rejected.
        #
        # supported patterns (case-insensitive):
        #   "example.com"   exact host
        #   "*.example.com" the apex "example.com" plus any subdomain at any depth
        def url_allowed?(url, patterns)
          url = url.to_s
          return false if url.blank?

          # Browsers normalize backslashes to forward slashes and strip embedded
          # tab/newline/space before parsing a URL, while Addressable does not.
          # Reject any URL containing a backslash or ASCII control/space char so
          # the host we validate is the host the browser actually navigates to,
          # closing parser-divergence open-redirect bypasses (DC-11).
          return false if url.match?(/[\\\x00-\x20\x7f]/)

          uri = Addressable::URI.parse(url)
          return false if uri.nil?

          # purely relative, first-party path (no scheme, no host, not protocol-relative "//host")
          return true if uri.scheme.blank? && uri.host.blank? && !url.start_with?('//')

          host = uri.host&.downcase&.chomp('.') # drop the optional FQDN root dot
          return false if host.blank? # scheme without host (javascript:, mailto:, ...)

          allowed = Array.wrap(patterns).map { |p| p.to_s.downcase }.compact_blank
          return false if allowed.empty?

          allowed.any? { |pattern| host_matches_pattern?(host, pattern) }
        rescue Addressable::URI::InvalidURIError
          false
        end

        def new_user_confirmation?
          configuration[:allowed_issuers]&.any? { |_, v| v.dig(:new_user_confirmation, :user_group).present? } || configuration[:new_user_confirmation].present?
        end

        def new_user_confirmations_issuer(group_name)
          configuration[:allowed_issuers]&.find { |_, v| v.dig(:new_user_confirmation, :user_group) == group_name }&.first.presence || configuration.dig(:new_user_confirmation, :user_group).presence&.then { |g| g == group_name ? 'internal' : nil }
        end

        def secret_key
          ENV['SECRET_KEY_BASE'].to_s
        end

        def secret_for_issuer(iss)
          return if iss.blank?

          if (public_key = configuration.dig(:allowed_issuers, iss, :public_key) || configuration.dig(:public_keys, iss)).present?
            OpenSSL::PKey::RSA.new(public_key)
          elsif iss.to_s == issuer.to_s
            secret_key
          end
        end

        def issuer
          configuration[:issuer] || 'datacycle.info'
        end

        def expires
          Time.zone.now + (configuration[:expiration_time] || 24.hours)
        end

        private

        def host_matches_pattern?(host, pattern)
          if pattern.start_with?('*.')
            suffix = pattern.delete_prefix('*.')
            host == suffix || host.end_with?(".#{suffix}")
          else
            host == pattern
          end
        end
      end
    end
  end
end
