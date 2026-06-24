# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class DataLinksController < ::DataCycleCore::Api::V4::ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::FilterConcern
        include DataCycleCore::ApiHelper
        include DryParams

        DATALINK_PARAMS_SCHEMA = DataCycleCore::BaseSchema.params do
          required(:@graph).value(:array, min_size?: 1).each(:hash) do
            required(:receiver).hash do
              required(:email).filled(:string)
              optional(:givenName).filled(:string)
              optional(:familyName).filled(:string)
              optional(:name).filled(:string)
            end
            required(:item).hash do
              required(:@id).filled(:string)
              optional(:@type).filled(:string, included_in?: ['Thing'])
            end
            required(:permission).filled(:string, included_in?: DataLink::PERMISSIONS.values)
            optional(:comment).maybe(:string)
            optional(:validFrom).filled(:date_time)
            optional(:validUntil).filled(:date_time)
          end
        end

        def create
          dl_params = data_link_params
          responses = []
          errors = []

          dl_params.each_with_index do |data, index|
            ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
              receiver = DataCycleCore::User.where(email: data.dig(:receiver, :email))
                .first_or_create(**data[:receiver], password: Devise.friendly_token)
              item = data[:item_type].constantize.find(data[:item_id])
              raise(Error::BadRequestError, { path: ['@graph', index, 'item', '@id'], message: "item not found with @id '#{data[:item_id]}'" }) if item.nil?

              allowed_permissions = DataCycleCore::DataLink.allowed_permissions(item, current_user)
              raise(Error::BadRequestError, { path: ['@graph', index, 'permission'], message: "'#{data[:permissions]}' not allowed" }) unless allowed_permissions.include?(data[:permissions])

              raise(Error::BadRequestError, I18n.with_locale(:en) { receiver.errors.messages.values.flatten.map { |m| { path: ['@graph', index, 'receiver'], message: m } } }) unless receiver.persisted?

              rraise(Error::BadRequestError, { path: ['@graph', index, 'receiver'], message: 'receiver is locked' }) if receiver.locked?
              raise(Error::BadRequestError, { path: ['@graph', index, 'receiver', 'email'], message: 'external_link already exists for this email' }) if DataCycleCore::DataLink.includes(:receiver).where(**data.slice(:item_id, :item_type), receiver: { email: receiver.email }).any?

              data_link = DataCycleCore::DataLink.create!(
                creator: current_user,
                **data.except(:receiver, :item),
                receiver: receiver
              )
              responses << {
                success: true,
                '@id': data_link.id,
                url: data_link_url(data_link)
              }
            rescue ActiveRecord::RecordNotFound, Error::BadRequestError => e
              responses << { success: false }
              if e.respond_to?(:formatted_errors)
                errors.concat(e.formatted_errors)
              else
                errors << { source: { parameter: ['@graph', index] }, title: e.class.name.demodulize, detail: e.message }
              end
            end
          end

          render json: { '@graph': responses, errors: errors }.compact_blank, status: errors.empty? ? :created : :multi_status
        end

        private

        def data_link_params
          params_for(DATALINK_PARAMS_SCHEMA)
            .deep_transform_keys { |key| key.to_s.underscore.to_sym }[:@graph]
            .map do |param|
              param[:receiver][:email]&.downcase! if param.dig(:receiver, :email).present?
              param[:valid_until] = param[:valid_until].in_time_zone.end_of_day if param[:valid_until].present?
              param[:permissions] = param.delete(:permission)
              param[:item_type] = param.dig(:item, :@type).presence || 'Thing'
              param[:item_type] = "DataCycleCore::#{param[:item_type]}"
              param[:item_id] = param.dig(:item, :@id)

              param
            end
        end
      end
    end
  end
end
