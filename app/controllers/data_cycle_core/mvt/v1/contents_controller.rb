# frozen_string_literal: true

module DataCycleCore
  module Mvt
    module V1
      class ContentsController < ::DataCycleCore::Api::V4::ContentsController
        before_action :check_feature_enabled

        def index
          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1

          ActiveRecord::Base.transaction do
            ActiveRecord::Base.connection.execute(ActiveRecord::Base.sanitize_sql_for_conditions(['SET LOCAL statement_timeout = ?', puma_max_timeout * 1000]))

            Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
              query = build_search_query

              render(json: query.query.to_bbox) && return if permitted_params[:bbox]

              I18n.with_locale(@language.first || I18n.locale) do
                render(plain: query.query.to_mvt(@x, @y, @z, layer_name: @layer_name, include_parameters: @include_parameters, fields_parameters: @fields_parameters, classification_trees_parameters: @classification_trees_parameters), content_type: request.format)
              end
            end
          end
        end

        def show
          @content = DataCycleCore::Thing
            .includes(:translations, :scheduled_data, classifications: [classification_aliases: [:classification_tree_label]])
            .find(permitted_params[:id])
          raise DataCycleCore::Error::Api::ExpiredContentError.new([{ pointer_path: request.path, type: 'expired_content', detail: 'is expired' }]), 'API Expired Content Error' unless @content.is_valid?

          render(plain: @content.to_mvt(@x, @y, @z, include_parameters: @include_parameters, fields_parameters: @fields_parameters, classification_trees_parameters: @classification_trees_parameters), content_type: request.format)
        end

        def permitted_parameter_keys
          super.union([:x, :y, :z, :bbox, :layerName])
        end

        def prepare_url_parameters
          super

          @x = permitted_params[:x]
          @y = permitted_params[:y]
          @z = permitted_params[:z]
          @layer_name = permitted_params[:layerName]
          @api_version = 1
        end

        def log_activity
          current_user.log_activity(type: "mvt_v#{@api_version}", data: permitted_params.to_h.merge(controller: params.dig('controller'), action: params.dig('action')))
        end

        def check_feature_enabled
          raise ActiveRecord::RecordNotFound if DataCycleCore.features.dig(:serialize, :serializers, :mvt) != true && !request.referer&.start_with?(Rails.application.config.action_mailer.default_url_options.slice(:protocol, :host)&.values&.join('://'))
        end
      end
    end
  end
end
