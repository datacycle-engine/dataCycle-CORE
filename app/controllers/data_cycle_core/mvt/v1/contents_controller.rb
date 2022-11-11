# frozen_string_literal: true

module DataCycleCore
  module Mvt
    module V1
      class ContentsController < ::DataCycleCore::Mvt::V1::MvtBaseController
        PUMA_MAX_TIMEOUT = 60
        include DataCycleCore::Filter
        # include DataCycleCore::ApiHelper
        before_action :prepare_url_parameters

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1

          ActiveRecord::Base.transaction do
            ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_for_conditions(['SET LOCAL statement_timeout = ?', puma_max_timeout * 1000]))

            Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
              query = build_search_query

              # TODO: include, fields, classification_trees
              I18n.with_locale(@language.first || I18n.locale) do
                render plain: query.query.to_mvt(permitted_params[:x], permitted_params[:y], permitted_params[:z], include_parameters: @include_parameters, fields_parameters: @fields_parameters, classification_trees_parameters: @classification_trees_parameters), content_type: request.format
              end
            end
          end
        end

        # TODO: show

        # For now we are disabling filter-parameters

        # def build_search_query
        #   endpoint_id = permitted_params[:id]
        #   @linked_stored_filter = nil
        #   if endpoint_id.present?
        #     @stored_filter = DataCycleCore::StoredFilter.find_by(id: endpoint_id)

        #     if @stored_filter
        #       authorize! :api, @stored_filter
        #       @linked_stored_filter = @stored_filter.linked_stored_filter if @stored_filter.linked_stored_filter_id.present?
        #     elsif (@watch_list = DataCycleCore::WatchList.without_my_selection.find_by(id: endpoint_id))
        #     else
        #       raise ActiveRecord::RecordNotFound
        #     end
        #   end

        #   filter = @stored_filter || DataCycleCore::StoredFilter.new

        #   filter.language = @language
        #   filter.parameters = current_user.default_filter(filter.parameters, { scope: 'api' })

        #   query = filter.apply(skip_ordering: true)

        #   query = query.watch_list_id(endpoint_id) unless @watch_list.nil?

        #   query = query.fulltext_search(@full_text_search) if @full_text_search
        #   query = append_filters(query, permitted_params)
        #   query
        # end

        def permitted_parameter_keys
          super.union([:x, :y, :z])
          # [:id, :token, :content_id, :format, :language, :x, :y, :z]
        end
      end
    end
  end
end
