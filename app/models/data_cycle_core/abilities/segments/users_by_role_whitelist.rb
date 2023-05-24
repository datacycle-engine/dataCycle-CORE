# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRoleWhitelist < Base
        attr_accessor :subject, :conditions

        def initialize(*whitelist)
          @subject = DataCycleCore::User
          @conditions = whitelist.include?('all') ? {} : { role: { name: whitelist } }
        end
      end
    end
  end
end
