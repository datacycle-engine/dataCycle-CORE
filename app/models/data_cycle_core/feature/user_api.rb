# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserApi < Base
      class << self
        def new_user_notification?
          configuration[:new_user_notification].present?
        end

        def users_to_notify
          emails = []

          emails.concat(DataCycleCore::UserGroup.find_by(name: configuration.dig(:new_user_notification, :user_group))&.users&.pluck(:email) || []) if configuration.dig(:new_user_notification, :user_group).present?

          emails.concat(Array.wrap(configuration.dig(:new_user_notification, :email)))

          emails.compact
        end

        def public_key_for_issuer?(issuer)
          configuration[:public_keys]&.key?(issuer)
        end

        def public_key_for_issuer(issuer)
          OpenSSL::PKey::RSA.new(configuration.dig(:public_keys, issuer))
        end

        def allowed_token_issuer(decoded)
          return unless public_key_for_issuer?(decoded['iss'])

          decoded['iss']
        end

        def json_additional_attributes
          (user_params['additional_attributes'] || {}).keys
        end

        def additional_tile_values(user)
          return unless enabled?

          tile_attributes = {}

          configuration[:additional_tile_attributes]&.each do |key, value|
            column = DataCycleCore::User.columns.find { |c| c.name == key }

            if column.type == :string
              tile_attributes[key] = user.try(key)
            elsif column.type == :jsonb
              tile_attributes.merge!(user.try(key)&.slice(*value.keys)&.transform_keys { |k| "#{key}/#{k}" } || {})
            end
          end

          tile_attributes
        end

        def user_params
          configuration[:user_params] || {}
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

        def allowed_user_params
          hash_to_allowed_params(user_params)
        end

        def notify_users(new_user)
          DataCycleCore::UserApiMailer.notify(users_to_notify, new_user).deliver_later
        end

        def default_user_groups
          return if configuration.dig(:default_user_groups).blank?

          DataCycleCore::UserGroup.where(name: configuration[:default_user_groups])
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
      end
    end
  end
end
