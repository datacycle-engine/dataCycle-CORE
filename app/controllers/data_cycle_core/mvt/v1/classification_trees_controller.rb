# frozen_string_literal: true

module DataCycleCore
  module Mvt
    module V1
      class ClassificationTreesController < ::DataCycleCore::Api::V4::ClassificationTreesController
        before_action :check_feature_enabled

        def select
          uuids = permitted_params[:uuids]&.split(',')

          if uuids.present? && uuids.is_a?(::Array) && uuids.size.positive?
            query = DataCycleCore::ClassificationPolygon
              .includes(:classification_alias)
              .where(classification_alias: { id: uuids })

            render(json: query.to_bbox) && return if permitted_params[:bbox]

            I18n.with_locale(@language.first || I18n.locale) do
              render(plain: query.to_mvt(@x, @y, @z, @layer_name), content_type: request.format.to_s)
            end
          else
            render json: { error: 'No ids given!' }, layout: false, status: :bad_request
          end
        end

        def permitted_parameter_keys
          super.union([:x, :y, :z, :uuids, :bbox, :layerName])
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
          current_user.log_activity(type: "mvt_v#{@api_version}", data: permitted_params.to_h.merge(
            controller: params.dig('controller'),
            action: params.dig('action'),
            referer: request.referer,
            origin: request.origin,
            middlewareOrigin: request.headers['X-Dc-Middleware-Origin']
          ))
        end

        def check_feature_enabled
          raise ActiveRecord::RecordNotFound if DataCycleCore.features.dig(:serialize, :serializers, :mvt) != true && !request.referer&.start_with?(Rails.application.config.action_mailer.default_url_options.slice(:protocol, :host)&.values&.join('://'))
        end
      end
    end
  end
end
