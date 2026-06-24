# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Refresh < Base
      def self.execute_all(data)
        Base.execute_all(data, 'refresh')
      end
    end
  end
end
