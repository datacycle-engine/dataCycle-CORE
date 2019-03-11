# frozen_string_literal: true

module DataCycleCore
  class FaradayRaiseExcept404 < Faraday::Response::RaiseError
    def on_complete(env)
      super(env) unless env[:status] == 404
    end
  end
end
