# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class FeatureController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :authorize_user, :prepare_url_parameters

        def index
          features = Array.wrap(DataCycleCore.features)
          render json: api_response_format(features) { features }.to_json
        end

        private

        def api_response_format(contents)
          {
            '@graph' => yield,
            'meta' => {
              total: contents.count
            }
          }
        end

        def authorize_user
          render json: { error: 'Forbidden' }, layout: false, status: :forbidden unless current_user&.is_role?('super_admin')
        end
      end
    end
  end
end
