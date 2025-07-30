# frozen_string_literal: true

module DataCycleCore
  module Update
    class Update < DataCycleCore::Update::Base
      def initialize(type:, template:, strategy:, transformation: nil)
        @type = type
        @template = template
        @transformation = transformation

        extend(strategy)

        update
      end
    end
  end
end
