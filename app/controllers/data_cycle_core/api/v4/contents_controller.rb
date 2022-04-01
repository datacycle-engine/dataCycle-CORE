# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ContentsController < ::DataCycleCore::Api::V4::ApiBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        include DataCycleCore::ApiHelper
        before_action :prepare_url_parameters

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1

          ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
            ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_for_conditions(['SET LOCAL statement_timeout = ?', puma_max_timeout * 1000]))

            Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
              query = build_search_query

              render(plain: query.query.to_geojson(include_parameters: @include_parameters, fields_parameters: @fields_parameters), content_type: request.format.to_s) && next if request.format.geojson?

              query = apply_ordering(query)

              @pagination_contents = apply_paging(query)
              @contents = @pagination_contents

              if list_api_request?
                render plain: list_api_request.to_json, content_type: 'application/json'
              else
                render 'index'
              end
            end
          end
        end

        def show
          @content = DataCycleCore::Thing
            .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            .find(permitted_params[:id])
          raise DataCycleCore::Error::Api::ExpiredContentError.new([{ pointer_path: request.path, type: 'expired_content', detail: 'is expired' }]), 'API Expired Content Error' unless @content.is_valid?

          render(plain: @content.to_geojson(include_parameters: @include_parameters, fields_parameters: @fields_parameters), content_type: request.format.to_s) && return if request.format.geojson?
        end

        def timeseries
          content = DataCycleCore::Thing
            .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            .find(permitted_params[:content_id] || permitted_params[:id])

          from = nil
          from = Time.parse(permitted_params.dig(:time, :in, :min)).in_time_zone if permitted_params.dig(:time, :in, :min).present?
          to = nil
          to = Time.parse(permitted_params.dig(:time, :in, :max)).in_time_zone if permitted_params.dig(:time, :in, :max).present?
          if permitted_params[:timeseries].in?(content.timeseries_property_names)
            method = permitted_params[:timeseries]
            @contents = content.send(method, from, to)
          else
            @contents = nil
          end

          case permitted_params[:format].to_sym
          when :json
            json = { error: "no timeseries data found for #{content.name}(#{content.id})" }
            json = { data: @contents.pluck(:timestamp, :value) } unless @contents.nil?
            render json: json
          when :csv
            response.headers['Content-Type'] = 'text/csv'
            response.headers['Content-Disposition'] = "attachment; filename=#{content.id}_#{permitted_params[:timeseries]}.csv"
            csv = ['timestamp; value']
            csv = (csv + @contents.pluck(:timestamp, :value).map { |line| line.join('; ') }).join("\n") if @contents.present?
            render plain: csv
          end
        end

        def select
          uuid = permitted_params[:uuid] || permitted_params[:uuids]&.split(',')
          if uuid.present? && uuid.is_a?(::Array) && uuid.size.positive?
            fetched_things = DataCycleCore::Thing
              .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
              .where(id: uuid)
            @contents = apply_paging(fetched_things)
            render 'index'
          else
            render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          end
        end

        def typeahead
          query = build_search_query
          result = query.typeahead(permitted_params[:search], @language, permitted_params[:limit] || 10)
          words = result.to_a.map { |i| i.dig('word') } # score not needed
          render json: {
            '@context' => api_plain_context(@language),
            '@graph' => {
              '@type' => 'dcls:Statistics',
              'suggest' => words
            }
          }
        end

        def deleted
          deleted_contents = DataCycleCore::Thing::History.where(
            DataCycleCore::Thing::History.arel_table[:deleted_at].not_eq(nil)
          )

          if permitted_params&.dig(:filter, :attribute, :'dct:deleted').present?
            filter = permitted_params[:filter][:attribute][:'dct:deleted'].to_h.deep_symbolize_keys
            filter.each do |operator, value|
              query_string = apply_timestamp_query_string(value, "#{deleted_contents.table.name}.deleted_at")
              if operator == :in
                deleted_contents = deleted_contents.where(query_string)
              elsif operator == :notIn
                deleted_contents = deleted_contents.where.not(query_string)
              end
            end
          end

          deleted_contents = deleted_contents.except(:order).order('deleted_at DESC')

          render plain: list_api_deleted_request(apply_paging(deleted_contents)).to_json, content_type: 'application/json'
        end

        def permitted_parameter_keys
          super + [:id, :language, :uuids, :search, :limit, :timeseries, uuid: []] + [filter: {}] + [time: {}] + ['dc:liveData': [:'@id', :minPrice]]
        end

        def permitted_filter_parameters
          {
            filter:
              attribute_filters + [linked: {}] + [union: []]
          }
        end

        private

        def list_api_request?
          return true if @include_parameters.blank? && select_attributes(@fields_parameters).include?('dct:modified') && select_attributes(@fields_parameters).size == 1
          false
        end
      end
    end
  end
end
