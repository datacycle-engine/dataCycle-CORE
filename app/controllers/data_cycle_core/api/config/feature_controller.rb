# frozen_string_literal: true

module DataCycleCore
  module Api
    module Config
      class FeatureController < ::DataCycleCore::Api::Config::ApiBaseController
        before_action :prepare_url_parameters

        def index
          authorize! :index, :api_config_features
          features = DataCycleCore.features.deep_reject { |k, _| k == 'public_keys' }
          features = Array.wrap(features)
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
      end
    end
  end
end
