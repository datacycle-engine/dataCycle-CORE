# frozen_string_literal: true

module DataCycleCore
  module Export
    class PushObject < GenericObject
      # attr_reader :external_system, :options, :locales, :logging
      #
      # def initialize(**options)
      #   # raise "Missing external_source for #{self.class}, options given: #{options}" if options[:external_source].blank?
      #   # raise "Missing source_type for #{self.class}, options given: #{options}"     if options[:import][:source_type].nil?
      #
      #   @external_system = options[:external_source]
      #   @options = options.with_indifferent_access
      #   @locales = options[:locales]
      #   @logging = init_logging(:export)
      # end
    end
  end
end
