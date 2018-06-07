# frozen_string_literal: true

module DataCycleCore
  module UserHelpers
    def full_name
      name || "#{given_name} #{family_name}"
    end
  end
end
