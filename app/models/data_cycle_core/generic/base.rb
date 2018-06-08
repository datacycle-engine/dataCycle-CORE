# frozen_string_literal: true

module DataCycleCore
  module Generic
    class RecoverableError < StandardError
    end

    class Base
      attr_reader :external_source

      def initialize(external_source_id)
        @external_source = DataCycleCore::ExternalSource.find(external_source_id)
      end

      def credentials
        external_source&.credentials
      end
    end
  end
end
