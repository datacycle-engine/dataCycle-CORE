# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class UsersByRoleWhitelist < Base
        attr_accessor :subject, :conditions

        def initialize(*whitelist)
          @subject = DataCycleCore::User
          @conditions = Array.wrap(whitelist).flatten.map(&:to_s).then { |wl| wl.include?('all') ? {} : { role: { name: wl } } }
        end
      end
    end
  end
end
