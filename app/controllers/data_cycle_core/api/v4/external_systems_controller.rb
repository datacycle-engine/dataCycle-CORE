# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsController < ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
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

        def update
          strategy, external_system = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          contents = Array.wrap(content_params.as_json)

          responses = contents.map do |content|
            strategy.update(content, external_system)
          end

          errors = responses.select { |i| i[:error].present? }

          render plain: responses.to_json, content_type: 'application/json', status: errors.size.positive? ? :bad_request : :ok
        end

        def create
          strategy, external_system = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          content = content_params.as_json

          response = strategy.create(content, external_system)
          errors = response[:error] || []

          render plain: Array.wrap(response).to_json, content_type: 'application/json', status: errors.size.positive? ? :bad_request : :ok
        end

        def destroy
          strategy, external_system = api_strategy
          render(json: { error: 'endpoint not active' }, status: :not_found) && return if strategy.nil?
          contents = Array.wrap(content_params.as_json)

          responses = contents.map do |content|
            strategy.delete(content, external_system)
          end

          errors = responses.select { |i| i[:error].present? }

          render plain: responses.to_json, content_type: 'application/json', status: errors.size.positive? ? :bad_request : :ok
        end

        private

        def search_feratel_api(search_method)
          external_system = DataCycleCore::ExternalSystem.find_by(id: permitted_params[:external_source_id])
          if external_system.blank? || external_system&.identifier != 'feratel'
            error = 'Only available for Feratel data.'
            render plain: { error: error }.to_json, content_type: 'application/json', status: :bad_request
            return
          end

          feratel_params = [:days, :units, :from, :to, :page_size, :start_index, :occupation]
          credentials = { options: permitted_params.slice(*feratel_params) }.merge(Array.wrap(external_system.credentials).first.symbolize_keys)
          endpoint = DataCycleCore::Generic::Feratel::Endpoint.new(credentials)
          search_data = endpoint.send(search_method)
          if search_data&.first.try(:'[]', 'error').present?
            error = search_data.first['error']
          else
            live_data = search_data
              .map { |i| { '@id' => DataCycleCore::Thing.find_by(external_key: i.dig('id'))&.id, 'minPrice' => i.dig('base_price') } }
              .select { |i| i.dig('@id').present? }
            content_ids = live_data.map { |i| i.dig('@id') }
            error = 'No suitable results found.' if content_ids.blank?
          end

          if error.present?
            render plain: { error: error }.to_json, content_type: 'application/json', status: :bad_request
          else
            query_params = permitted_params
              .except(:external_source_id, :controller, :action, :format, :endpoint_id, *feratel_params)
              .merge('filter' => (permitted_params[:filter] || {}).merge({ 'contentId' => { 'in' => [content_ids.join(',')] } }), 'dc:liveData' => live_data, id: permitted_params[:endpoint_id])
              .to_hash
              .deep_symbolize_keys
            @permitted_params = query_params

            query = build_search_query
            query = apply_ordering(query)
            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents

            # @TODO: fix me! sort_random with seed is not working for services?
            # filtered_content_ids = @contents&.ids
            # @permitted_params[:'dc:liveData'] = @permitted_params[:'dc:liveData']&.select { |i| i[:'@id'].in?(filtered_content_ids) }

            render template: 'data_cycle_core/api/v4/contents/index'
          end
        end

        def content_params
          return params[:@graph] if params.key?(:@graph)
          params
        end

        def permitted_parameter_keys
          super + [:external_source_id, :type, :external_key, :webhook_source, :endpoint_id,
                   :days, :units, :from, :to, :page_size, :start_index,
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
