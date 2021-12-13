# frozen_string_literal: true

module DataCycleCore
  class CustomDeviseFailureApp < Devise::FailureApp
    def http_auth?
      binding.pry

      super

      # if request.xhr?
      #   Devise.http_authenticatable_on_xhr
      # else
      #   !(request_format && is_navigational_format?)
      # end
    end

    def http_auth_body
      if request_format == :json
        return {
          errors: [
            {
              source: {
                pointer: request.env['REQUEST_PATH']
              },
              detail: i18n_message
            }
          ]
        }.to_json
      end

      super
    end
  end
end
