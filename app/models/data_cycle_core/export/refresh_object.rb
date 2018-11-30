# frozen_string_literal: true

module DataCycleCore
  module Export
    class RefreshObject < GenericObject
      attr_reader :external_system, :options, :locales, :logging, :endpoint

      def initialize(**options)
        raise "Missing external_system for #{self.class}, options given: #{options}" if options[:external_system].blank?

        @external_system = options[:external_system]
        @options = options.with_indifferent_access
        @logging = init_logging(:refresh)
        @endpoint = @external_system.refresh_config[:endpoint].constantize.new(options[:external_system].credentials.symbolize_keys)
      end
    end
  end
end
