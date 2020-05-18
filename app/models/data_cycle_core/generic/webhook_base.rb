# frozen_string_literal: true

module DataCycleCore
  module Generic
    class WebhookBase
      attr_reader :external_source, :target_type, :external_key, :access_token

      def initialize(external_source, _type, external_key, access_token)
        @external_source = external_source
        @external_key = external_key
        @access_token = access_token
      end
    end
  end
end
