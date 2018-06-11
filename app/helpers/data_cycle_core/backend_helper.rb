# frozen_string_literal: true

module DataCycleCore
  module BackendHelper
    def get_user_for_id(id)
      DataCycleCore::User.find(id)
    end
  end
end
