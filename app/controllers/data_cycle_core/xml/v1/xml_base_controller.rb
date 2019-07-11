# frozen_string_literal: true

module DataCycleCore
  module Xml
    module V1
      class XmlBaseController < ::DataCycleCore::Api::V3::ApiBaseController
        helper DataCycleCore::XmlHelper

        private

        def access_denied(_exception)
          render 'error', locals: { error: 'you need to be logged in to export xml data.', status: :access_denied }
        end

        def not_found(exception)
          render 'error', locals: { error: exception.message, status: :not_found }
        end

        def set_default_response_format
          request.format = :xml
        end
      end
    end
  end
end
