# frozen_string_literal: true

module DataCycleCore
  module Generic
    class GenericObject
      attr_accessor :mode
      attr_reader :external_source, :options, :source_type, :source_object, :database_name, :logger, :strategy

      def initialize(type:, **options)
        @options = options.with_indifferent_access

        raise "Missing external_source for #{self.class}, options given: #{@options}" if @options[:external_source].blank?

        @strategy = @options.dig(type, "#{type}_strategy").safe_constantize
        raise "Missing source_type for #{self.class}, options given: #{@options}" if @options.dig(type, :source_type).blank? && !@strategy.try(:source_type?).is_a?(FalseClass)

        @external_source = @options[:external_source]

        if @options.dig(type, :source_type).present?
          @source_object = DataCycleCore::Generic::Collection
          @source_type = Mongoid::PersistenceContext.new(@source_object, collection: @options.dig(type, :source_type))
          @database_name = "#{@source_type.database_name}_#{@external_source.id}"
        end

        @mode = options.dig(type, :mode)&.to_sym || options.dig(:mode)&.to_sym || :incremental
        @logger = init_logging(type)
      end

      def self.init_logging(type)
        return if type.blank?

        DataCycleCore::Generic::Logger::Instrumentation.new(type.to_s)
      end

      delegate :init_logging, to: :class

      def self.format_float(number, n, m)
        parts = number.round(m).to_s.split('.')
        parts[0].prepend(' ').rjust(n, '.') + '.' + parts[1].ljust(m, '0')
      end
    end
  end
end
