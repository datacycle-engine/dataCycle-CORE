# frozen_string_literal: true

module DataCycleCore
  module Generic
    class ImportObject < GenericObject
      attr_reader :external_source, :options, :locales, :logging, :source_type, :source_object

      def initialize(**options)
        raise "Missing external_source for #{self.class}, options given: #{options}" if options[:external_source].blank?
        raise "Missing source_type for #{self.class}, options given: #{options}"     if options[:import][:source_type].nil?

        @external_source = options[:external_source]
        @options = options.with_indifferent_access
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options[:import][:source_type])
        @locales = options[:locales]
        @logging = init_logging(:import)
      end
    end
  end
end