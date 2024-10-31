# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsController < ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::FilterConcern
        include DataCycleCore::ApiHelper
        before_action :prepare_url_parameters

        def show
          external_system_id = DataCycleCore::ExternalSystem.find_by(identifier: permitted_params[:external_source_id])&.id || permitted_params[:external_source_id]

          content = DataCycleCore::Thing.by_external_key(external_system_id, permitted_params[:external_key]).first

          raise ActiveRecord::RecordNotFound if content.nil?

          redirect_to api_v4_thing_path({ id: content.id }.merge(params.except(:external_key, :external_source_id, :controller, :action, :format).to_unsafe_hash))
        end

        def permitted_params
          @permitted_params ||= params.permit(*permitted_parameter_keys)
        end

        def search_availability
          search_feratel_api(:search_availabilities)
        end

        def search_additional_service
          search_feratel_api(:search_additional_services)
        end

        def create
          response, status = content_request(type: :create)

          render plain: response.to_json, content_type: 'application/json', status:
        end

        def update
          response, status = content_request(type: :update)

          render plain: response.to_json, content_type: 'application/json', status:
        end

        def destroy
          response, status = content_request(type: :delete)

          render plain: response.to_json, content_type: 'application/json', status:
        end

        def timeseries
          external_system = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id])

          render(json: { error: 'unknown endpoint' }, status: :not_found) && return if external_system.blank?

          content = DataCycleCore::Thing.first_by_external_key_or_id(permitted_params[:external_key], external_system.id)

          render(json: { error: 'content not found' }, status: :not_found) && return if content.blank?
          render(json: { error: 'attribute_name missing' }, status: :not_found) && return if permitted_params[:attribute].present? && content.timeseries_property_names.exclude?(permitted_params[:attribute])

          data = data_from_request(content)

          head(:no_content) && return if data.blank?

          response = Timeseries.create_all(content, data)

          render plain: response.to_json, content_type: 'application/json', status: response[:error].present? ? :bad_request : :accepted
        end

        private

        def csv_request?
          permitted_params[:format].to_sym == :csv || Mime::Type.parse(request.content_type.to_s)&.first&.to_sym == :csv
        end

        def data_from_request(content)
          to_timeseries = ->(s) { { thing_id: content.id, property: s[0], timestamp: s[1], value: s[2] } }
          mapper = ->(s, a) { s&.map { |v| to_timeseries.call(v.unshift(a)) } }

          if csv_request?
            csv = CSV.parse(request.body)
            permitted_params[:attribute].present? ? mapper.call(csv, permitted_params[:attribute]) : csv&.select { |v| v[0].in?(content.timeseries_property_names) }&.map(&to_timeseries)
          elsif permitted_params[:attribute].present?
            mapper.call(params[:data], permitted_params[:attribute])
          else
            timeseries_params(content).to_h.flat_map { |k, v| mapper.call(v, k) }
          end
        end

        def timeseries_params(content)
          params.slice(*content.timeseries_property_names).permit!
        end

        def content_request(type: :update)
          strategy, external_system = api_strategy
          @webhook_logger ||= ::Logger.new('./log/APIv4_webhook.log')
          @webhook_logger.info("[Request #{request.request_id}] Incoming webhook (APIv4) for external system '#{external_system.identifier}'. User #{current_user.id} #{current_user.email}. Payload: #{content_params}")

          return_logger = lambda { |return_status, data|
            @webhook_logger.info("[#{return_status}] [Request #{request.request_id}] Returning for webhook (APIv4). Return value: #{data}")
          }

          if strategy.nil?
            return_value = { error: 'endpoint not active'}
            status = :not_found
            return_logger.call(status, return_value)
            return return_value, status
          end

          locale = params.dig(:@context, :@language)
          locale = I18n.available_locales.first if locale.blank?
          unless locale.to_sym.in?(I18n.available_locales)
            return_value = { error: 'Invalid locale. Allowed are: ' + I18n.available_locales.join(', ') }
            status = :bad_request
            return_logger.call(status, return_value)
            return return_value, status
          end

          I18n.with_locale(locale) do
            responses = content_params.map do |data|
              if strategy.method(type).arity == 3
                strategy.send(type, data, external_system, current_user)
              else
                strategy.send(type, data, external_system)
              end
            end

            error_present = responses.any? { |i| i[:error].present? }
            return_value = responses
            unless responses.size == 1
              status = error_present ? :bad_request : :ok
              return_logger.call(status, return_value)
              return return_value, status
            end
            status = responses.first[:status].present? ? responses.first[:status] : error_present ? :bad_request : :ok
            responses.first.delete(:status)
            return_logger.call(status, return_value)
            return return_value, status
          end
        end

        def search_feratel_api(search_method)
          external_system = DataCycleCore::ExternalSystem.find_by(id: permitted_params[:external_source_id])
          if external_system.blank? || external_system&.identifier != 'feratel'
            error = 'Only available for Feratel data.'
            render plain: { error: }.to_json, content_type: 'application/json', status: :bad_request
            return
          end

          feratel_params = [:days, :units, :from, :to, :page_size, :start_index, :occupation]
          credentials = { options: permitted_params.slice(*feratel_params) }.merge(Array.wrap(external_system.credentials).first.symbolize_keys)
          endpoint = DataCycleCore::Generic::Feratel::Endpoint.new(**credentials)
          search_data = endpoint.send(search_method)
          if search_data&.first.try(:[], 'error').present?
            error = search_data.first['error']
          else
            live_data = search_data
              .map { |i| { '@id' => DataCycleCore::Thing.find_by(external_key: i.dig('id'))&.id, 'minPrice' => i.dig('base_price') } }
              .select { |i| i.dig('@id').present? }
            content_ids = live_data.map { |i| i.dig('@id') }
            error = 'No suitable results found.' if content_ids.blank?
          end

          if error.present?
            render plain: { error: }.to_json, content_type: 'application/json', status: :bad_request
          else
            query_params = permitted_params
              .except(:external_source_id, :controller, :action, :format, :endpoint_id, *feratel_params)
              .merge('filter' => (permitted_params[:filter] || {}).merge({ 'contentId' => { 'in' => [content_ids.join(',')] } }), 'dc:liveData' => live_data, id: permitted_params[:endpoint_id])
              .to_hash
              .deep_symbolize_keys
            @permitted_params = query_params

            query = build_search_query
            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents

            render template: 'data_cycle_core/api/v4/contents/index'
          end
        end

        def content_params
          Array.wrap(params.fetch(:@graph) { params }).map { |p| p.permit!.to_h }
        end

        def permitted_parameter_keys
          super + [:external_source_id, :type, :external_key, :webhook_source, :endpoint_id,
                   :days, :units, :from, :to, :page_size, :start_index, :attribute,
                   occupation: [:adults, :children, :units], filter: {}]
        end

        def api_strategy
          external_system = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id])
          api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_system.config['api_strategy'] }

          return api_strategy&.constantize&.new(external_system, permitted_params[:type], permitted_params[:external_key], permitted_params[:token]), external_system
        end
      end
    end
  end
end
