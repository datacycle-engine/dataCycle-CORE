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

          if errors.present?
            {
              error: errors
            }
          else
            {
              create: result[:content]&.id,
              title: result[:content].try(:title),
              link: data_link_url(result[:data_link])
            }
          end
        end

        private

        def create_data_link(data)
          receiver = DataCycleCore::User.where(email: data['email']).first_or_create!(data.slice('email', 'given_name', 'family_name').merge(password: SecureRandom.hex, role: DataCycleCore::Role.find_by(name: 'guest')))

          if data['@id'].present?
            content = DataCycleCore::Thing.find(data['@id'])
          else
            content = DataCycleCore::DataHashService.create_internal_object(@external_source.default_options&.[]('template'), { datahash: data.slice('name') }, receiver)
          end

          data_link = DataCycleCore::DataLink.new
          data_link.creator = receiver
          data_link.receiver = receiver
          data_link.item = content
          data_link.permissions = @external_source.default_options&.[]('permissions') || 'write'
          data_link.valid_from = ERB.new(@external_source.default_options['valid_from']).result&.in_time_zone if @external_source.default_options&.key?('valid_from')
          data_link.valid_until = ERB.new(@external_source.default_options['valid_until']).result&.in_time_zone if @external_source.default_options&.key?('valid_until')
          data_link.comment = data['comment']
          data_link.save

          DataCycleCore::DataLinkMailer.mail_external_link(data_link, data_link_url(data_link), @external_source.default_options&.[]('instructions_url'), @external_source.identifier).deliver_later if send_mail?(data)

          {
            content: content,
            data_link: data_link,
            error: receiver.valid? && content.valid? && data_link.valid? ? nil : 'Es ist ein Fehler aufgetreten'
          }
        end

        def send_mail?(data)
          return data['send_mail'] if data.key?('send_mail')
          return @external_source.default_options['send_mail'] if @external_source.default_options&.key?('send_mail')

          true
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
          required(:givenName).filled(:string)
          required(:familyName).filled(:string)
          required(:email).filled(:string)
          optional(:title).filled(:string)
          optional(:@id).filled(:string)
          optional(:comment).filled(:string)
          optional(:sendMail).filled(:bool)
        end

        rule(:email) do
          key.failure('has invalid format') unless value.match?(Devise.email_regexp)
        end

        rule(:title) do
          key.failure('is required') if value.blank? && values.dig(:@id).blank?
        end

        rule(:@id) do
          key.failure('is required') if value.blank? && values.dig(:title).blank?
        end
      end
    end
  end
end
