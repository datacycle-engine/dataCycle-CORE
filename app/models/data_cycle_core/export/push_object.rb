# frozen_string_literal: true

module DataCycleCore
  module Export
    class PushObject < GenericObject
      attr_reader :external_system, :options, :locales, :logging, :endpoint

      def initialize(**options)
        raise "Missing external_system for #{self.class}, options given: #{options}" if options[:external_system].blank?

        @external_system = options[:external_system]
        @options = options.with_indifferent_access
        @logging = init_logging(:export)
        @endpoint = @external_system.push_config[:endpoint].constantize.new(options[:external_system].credentials.symbolize_keys)
      end
    end
  end
end
