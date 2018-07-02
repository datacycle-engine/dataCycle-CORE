# frozen_string_literal: true

module DataCycleCore
  module Api
    class ExternalSource
      attr_reader :external_source, :target_type, :external_key

      def initialize(external_source, type, external_key)
        @external_source = external_source
        @target_type = "DataCycleCore::#{type.classify}".safe_constantize
        @external_key = external_key
      end
    end
  end
end
