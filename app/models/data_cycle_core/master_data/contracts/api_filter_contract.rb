# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Contracts
      class ApiFilterContract < BaseContract
        params(FILTER, ATTRIBUTE_FILTER)
      end
    end
  end
end
