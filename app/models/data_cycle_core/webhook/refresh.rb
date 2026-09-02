# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Refresh < Base
      def self.execute_all(data, external_system_id: nil)
        Base.execute_all(data, 'refresh', external_system_id:)
      end
    end
  end
end
