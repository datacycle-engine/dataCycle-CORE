# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank4
      include CanCan::Ability

      def initialize(_user, _session = {})
      end
    end
  end
end
