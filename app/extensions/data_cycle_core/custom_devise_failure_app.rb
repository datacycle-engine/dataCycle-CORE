# frozen_string_literal: true

module DataCycleCore
  class CustomDeviseFailureApp < Devise::FailureApp
    def http_auth_body
      if request_format == :json
        return {
          errors: [
            {
              source: {
                pointer: attempted_path
              },
              detail: i18n_message(:unauthenticated_json)
            }
          ]
        }.to_json
      end

      super
    end
  end
end
