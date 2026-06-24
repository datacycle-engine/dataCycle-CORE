# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsController < ApiBaseController
        include DataCycleCore::ApiHelper
        include DataCycleCore::FilterConcern
        include DataCycleCore::FilterConceptConcern

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
          @pagination_url = method(:api_v4_external_source_search_availability_url)
          search_feratel_api(:search_availabilities)
        end

        def search_additional_service
          @pagination_url = method(:api_v4_external_source_search_additional_service_url)
          search_feratel_api(:search_additional_services)
        end

        def facets_feratel_locations
          @pagination_url = method(:api_v4_external_source_facets_feratel_locations_url)

          facets_feratel_api
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

          data = TimeseriesTransformation.new(external_system.transformations).apply(data)

          response = Timeseries.create_all(content, data)

          render plain: response.to_json, content_type: 'application/json', status: response[:error].present? ? :bad_request : :accepted
        end

        def demote
          response, status = content_request(type: :demote)

          render plain: response.to_json, content_type: 'application/json', status:
        end

        private

        def permitted_parameter_keys
          super + [:external_source_id, :type, :external_key, :webhook_source, :endpoint_id,
                   :days, :units, :from, :to, :page_size, :start_index, :attribute, :language, :classification_id, :classification_ids, :min_count_with_subtree, :min_count_without_subtree, :minCountWithSubtree, :minCountWithoutSubtree,
                   { occupation: [:adults, :children, :units], filter: {} }]
        end

        def data_from_request(content)
          to_timeseries = ->(s) { { thing_id: content.id, property: s[0], timestamp: s[1], value: s[2] } }
          mapper = lambda { |s, a|
            s = [s] unless s&.first.is_a?(Array)
            s&.map { |v| to_timeseries.call(v.unshift(a)) }
          }

          if csv_request?
            csv = CSV.parse(request.body)
            permitted_params[:attribute].present? ? mapper.call(csv, permitted_params[:attribute]) : csv&.select { |v| v[0].in?(content.timeseries_property_names) }&.map(&to_timeseries)
          elsif permitted_params[:attribute].present?
            mapper.call(params[:data], permitted_params[:attribute])
          else
            timeseries_params(content).flat_map { |k, v| mapper.call(v, k) }
          end
        end

        # Extracts timeseries data from the incoming request parameters,
        # ensuring that only valid properties defined for the content are processed.
        # The format for each entry in the data should be [[timestamp, value], ...], and the property name is determined by the key in the parameters. The Rest is ignored to prevent forwarding of any attacker-supplied keys.
        def timeseries_params(content)
          params.slice(*content.timeseries_property_names).to_unsafe_h
        end

        def csv_request?
          permitted_params[:format].to_sym == :csv || Mime::Type.parse(request.content_type.to_s)&.first&.to_sym == :csv
        end

        def content_request(type: :update)
          strategy, external_system = api_strategy
          @webhook_logger ||= ::Logger.new('./log/APIv4_webhook.log')
          @webhook_logger.info("[Request #{request.request_id}] Incoming webhook (APIv4) for external system '#{external_system.identifier}'. User #{current_user.id} #{current_user.email}. Payload: #{content_params}")

          return_logger = lambda { |return_status, data|
            @webhook_logger.info("[#{return_status}] [Request #{request.request_id}] Returning for webhook (APIv4). Return value: #{data}")
          }

          if strategy.nil?
            return_value = { error: 'endpoint not active' }
            status = :not_found
            return_logger.call(status, return_value)
            return return_value, status
          end

          locale = params.dig(:@context, :@language)
          locale = I18n.default_locale if locale.blank?
          unless locale.to_sym.in?(I18n.available_locales)
            return_value = { error: "Invalid locale. Allowed are: #{I18n.available_locales.join(', ')}" }
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
            status = if responses.first[:status].present?
                       responses.first[:status]
                     else
                       error_present ? :bad_request : :ok
                     end
            responses.first.delete(:status)
            return_logger.call(status, return_value)
            return return_value, status
          end
        end

        # Checks if the external system has an allowed API strategy and initializes it with the necessary parameters.
        # This strategy determines how the incoming data should be processed based on the external system's configuration.
        def api_strategy
          external_system = DataCycleCore::ExternalSystem.find(permitted_params[:external_source_id])
          api_strategy = DataCycleCore.allowed_api_strategies.find { |object| object == external_system.config['api_strategy'] }

          return api_strategy&.constantize&.new(external_system, permitted_params[:type], permitted_params[:external_key], permitted_params[:token]), external_system
        end

        # permit!s flexible data structures in the incoming payload.
        #
        # As the structure of the incoming data can vary significantly between different external systems,
        # we allow for a flexible approach to parameter handling.
        # The content_params method extracts the relevant data from the request,
        # permitting all parameters within the @graph key (or the entire payload if @graph is not present)
        # without strict schema validation.
        # This allows for maximum flexibility in handling diverse data formats and structures
        # that may be sent by different external systems.
        #
        # The API strategy handles the validation and processing of the data,
        # according to the specific requirements of the external system.
        def content_params
          Array.wrap(params.fetch(:@graph) { params }).map(&:to_unsafe_h)
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

          if external_system.module_base.present?
            endpoint_class = external_system.endpoint_module

            if endpoint_class.nil?
              error = 'Configured Endpoint Module not found.'
              render plain: { error: }.to_json, content_type: 'application/json', status: :bad_request
              return
            end

            endpoint = endpoint_class.new(**credentials)
          else
            endpoint = DataCycleCore::Generic::Feratel::Endpoint.new(**credentials)
          end

          search_data = endpoint.send(search_method)
          if search_data&.first.try(:[], 'error').present?
            error = search_data.first['error']
          else
            thing_ids = DataCycleCore::Thing.where(external_key: search_data.pluck('id')).pluck(:external_key, :id).to_h
            live_data = search_data
              .map { |i| { '@id' => thing_ids[i['id']], 'minPrice' => i['base_price'], **i.except('id', 'base_price') } }
              .select { |i| i['@id'].present? }
            content_ids = live_data.pluck('@id')
            error = 'No suitable results found.' if content_ids.blank?
          end

          if error.present?
            render plain: { error: }.to_json, content_type: 'application/json', status: :bad_request
          else
            permitted = permitted_params
              .except(:external_source_id, :controller, :action, :format, :endpoint_id, *feratel_params)
              .to_h
            validate_api_params(permitted, validate_params_exceptions, self.class::VALIDATE_PARAMS_CONTRACT)

            @permitted_params = permitted
              .deep_merge({
                'filter' => { 'contentId' => { 'in' => [content_ids.join(',')] } },
                'dc:liveData' => live_data,
                'id' => permitted_params[:endpoint_id]
              })
              .deep_symbolize_keys

            query = build_search_query
            @pagination_contents = apply_paging(query)
            @contents = @pagination_contents

            render template: 'data_cycle_core/api/v4/contents/index'
          end
        end

        def facets_feratel_api
          external_system = DataCycleCore::ExternalSystem.find_by(id: permitted_params[:external_source_id])

          type = feratel_facets_params[:type]
          if type.blank? || !type.in?(Datacycle::Connector::FeratelDeskline::Facets::Locations::ALLOWED_TYPES)
            error = 'Invalid or missing type parameter. Allowed types are: accommodations, addservices.'
            render json: { error: }, status: :bad_request
            return
          end

          min_count_without_subtree = (permitted_params[:min_count_without_subtree] || permitted_params[:minCountWithoutSubtree]).to_i
          min_count_with_subtree = (permitted_params[:min_count_with_subtree] || permitted_params[:minCountWithSubtree]).to_i
          @classification_tree_label = DataCycleCore::ClassificationTreeLabel.find_by!(name: 'Feratel - Orte')
          facets = Datacycle::Connector::FeratelDeskline::Facets::Locations.new(external_system, type, @classification_tree_label)
          facets_data = facets.facetted_locations || {}
          @classification_aliases = build_concepts_search_query(@classification_tree_label.classification_aliases)

          if min_count_without_subtree.positive?
            filtered_facets_data = facets_data.select { |_, v| v[:countWithoutSubtree] >= min_count_without_subtree }
            @classification_aliases = @classification_aliases.where(id: filtered_facets_data.keys)
          end

          if min_count_with_subtree.positive?
            filtered_facets_data = facets_data.select { |_, v| v[:count] >= min_count_with_subtree }
            @classification_aliases = @classification_aliases.where(id: filtered_facets_data.keys)
          end

          @classification_aliases.each do |c|
            c.thing_count_without_subtree = facets_data.dig(c.id, :countWithoutSubtree)
            c.thing_count_with_subtree = facets_data.dig(c.id, :count)
          end
          @classification_trees_parameters = []
          @classification_trees_filter = false

          if error.present?
            render json: { error: }, status: :bad_request
          else
            render template: 'data_cycle_core/api/v4/classification_trees/facets', content_type: 'application/json', status: :ok
          end
        rescue StandardError => e
          render json: { error: e.message }, status: :bad_request
        end

        def feratel_facets_params
          params.permit(:type)
        end
      end
    end
  end
end
