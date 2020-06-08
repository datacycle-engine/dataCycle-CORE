# frozen_string_literal: true

module DataCycleCore
  module Webhook
    class Delete < Base
      def self.execute_all(data)
        Base.execute_all(data, 'delete')
      end
    end
  end
end
