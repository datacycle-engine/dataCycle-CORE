# frozen_string_literal: true

module DataCycleCore
  module Xml
    module V1
      class XmlBaseController < ::DataCycleCore::Api::V3::ApiBaseController
        helper DataCycleCore::XmlHelper

        private

        def access_denied(exception)
          render 'error', error: exception.message, status: :access_denied
        end

        def not_found(exception)
          render 'error', error: exception.message, status: :not_found
        end

        def set_default_response_format
          request.format = :xml
        end
      end
    end
  end
end
