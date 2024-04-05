# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Base
      extend BaseFunctions
      attr_reader :content

      def initialize(content: nil)
        @content = content
      end
    end
  end
end
