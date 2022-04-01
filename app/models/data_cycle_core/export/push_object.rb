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

        endpoint_options = options[:external_system].credentials(:export)
        endpoint_options[:data] = @external_system.data if @external_system.data.present?
        endpoint_options ||= {}
        @endpoint = @external_system.export_config[:endpoint].constantize.new(endpoint_options.symbolize_keys)
      end
    end
  end
end
