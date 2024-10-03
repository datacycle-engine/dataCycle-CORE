# frozen_string_literal: true

module DataCycleCore
  module Generic
    class GenericObject
      attr_accessor :mode
      attr_reader :external_source, :options, :source_type, :source_object, :database_name, :logger, :strategy, :locales, :locale, :type, :step_name

      def initialize(**options)
        @options = options.with_indifferent_access
        @type = self.class::TYPE
        @step_name = options.dig(type, :name)

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
        @locales = Array.wrap(@options[:locales]).map(&:to_sym)
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

      def step_label(opts = {})
        label = []
        label.push(external_source&.name) if external_source&.name.present?
        label.push(opts.dig(type, :name)) if opts.dig(type, :name).present?
        step_options = []
        step_options.push("[#{opts[:credentials_index]}]") if opts[:credentials_index].present?
        step_options.push("[#{Array.wrap(opts&.dig(:download, :read_type)).join(', ')}]") if opts&.dig(:download, :read_type).present?
        step_options.push("[#{Array.wrap(opts[:locales]).join(', ')}]") if opts[:locales].present?
        label.push(step_options.join) if step_options.present?
        label.join(' ')
      end
    end
  end
end
