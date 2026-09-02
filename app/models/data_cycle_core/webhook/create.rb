# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Create < Base
      def self.execute_all(data, external_system_id: nil)
        Base.execute_all(data, 'create', external_system_id:)
      end
    end
  end
end
