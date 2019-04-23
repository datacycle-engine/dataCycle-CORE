# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Create < Base
      def self.execute_all(data)
        Base.execute_all(data, 'create')
      end
    end
  end
end
