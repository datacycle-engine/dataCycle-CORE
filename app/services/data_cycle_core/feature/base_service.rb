# frozen_string_literal: true

module DataCycleCore
  module Feature
    class BaseService
      def self.call(content)
        new(content).call
      end

      def call
        process
      end

      private

      attr_reader :content

      def initialize(content)
        @content = content
      end
    end
  end
end
