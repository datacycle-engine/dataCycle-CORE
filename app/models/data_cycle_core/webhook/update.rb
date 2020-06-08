# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Update < Base
      def self.execute_all(data)
        Base.execute_all(data, 'update')
      end
    end
  end
end
