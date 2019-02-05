# frozen_string_literal: true

module DataCycleCore
  module Api
    class ExternalSource
      attr_reader :external_source, :target_type, :external_key

      def initialize(external_source, _type, external_key)
        @external_source = external_source
        @external_key = external_key
      end
    end
  end
end
