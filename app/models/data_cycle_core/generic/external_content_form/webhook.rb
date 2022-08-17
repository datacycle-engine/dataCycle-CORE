# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ExternalContentForm
      class Webhook < DataCycleCore::Generic::Common::Webhook
        include DataCycleCore::Engine.routes.url_helpers

        def create(raw_data, _external_system)
          validator = ExternalContentFormContract.new
          errors = validator.call(raw_data.deep_symbolize_keys).errors.to_h || {}

          return { error: errors } if errors.present?
          data = Transformations.transformation.call(raw_data)
          result = {}

          init_logging do |logging|
            result = create_data_link(data)

            if result[:error].present?
              logging.error('create', data['name'], raw_data, result[:error])
              errors = result[:error]
            else
              logging.info("create Event: #{result[:content]&.id}", "transformed_data: #{data}")
            end
          end

          errors.present? ? { error: errors } : { create: result[:content]&.id, title: data['name'], link: data_link_url(result[:data_link]) }
        end

        private

        def create_data_link(data)
          receiver = DataCycleCore::User.where(email: data['email']).first_or_create!(data.slice('email', 'given_name', 'family_name').merge(password: SecureRandom.hex, role: DataCycleCore::Role.find_by(name: 'guest')))

          content = DataCycleCore::DataHashService.create_internal_object(@external_source.default_options&.[]('template'), { datahash: data.slice('name') }, receiver)

          data_link = DataCycleCore::DataLink.new
          data_link.creator = receiver
          data_link.receiver = receiver
          data_link.item = content
          data_link.permissions = @external_source.default_options&.[]('permissions') || 'write'
          data_link.save

          DataCycleCore::DataLinkMailer.mail_external_link(data_link, data_link_url(data_link), @external_source.default_options&.[]('instructions_url')).deliver_later

          {
            content: content,
            data_link: data_link,
            error: receiver.valid? && content.valid? && data_link.valid? ? nil : 'Es ist ein Fehler aufgetreten'
          }
        end

        def default_url_options
          Rails.application.config.action_mailer.default_url_options
        end

        def init_logging
          logging = DataCycleCore::Generic::GenericObject.new.init_logging(:create_event_link_external_system)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end

      class ExternalContentFormContract < DataCycleCore::MasterData::Contracts::GeneralContract
        params do
          required(:title).filled(:string)
          required(:givenName).filled(:string)
          required(:familyName).filled(:string)
          required(:email).filled(:string)
        end

        rule(:email) do
          key.failure('has invalid format') unless value.match?(Devise.email_regexp)
        end
      end
    end
  end
end
