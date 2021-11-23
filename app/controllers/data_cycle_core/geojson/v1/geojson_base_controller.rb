# frozen_string_literal: true

module DataCycleCore
  module Geojson
    module V1
      class GeojsonBaseController < ::DataCycleCore::Api::V4::ApiBaseController

        # private

        # def access_denied(_exception)
        #   render 'error', locals: { error: 'you need to be logged in to export geojson data.', status: :access_denied }
        # end

        # def not_found(exception)
        #   render 'error', locals: { error: exception.message, status: :not_found }
        # end

        # def set_default_response_format
        #   request.format = :geojson
        # end
      end
    end
  end
end
