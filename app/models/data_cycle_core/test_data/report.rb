# frozen_string_literal: true

module DataCycleCore
  module TestData
    # Collects the outcome of a generation run for human-readable reporting.
    class Report
      def initialize
        @successes = {} # template_name => [filled property names]
        @skips = {}      # template_name => [{ property:, type:, reason: }]
        @failures = {}   # template_name => [messages]
        @life_cycle_set = []
        @life_cycle_disabled = false
      end

      # Records a template whose record was filled successfully.
      def add_success(template_name, keys)
        @successes[template_name] = keys
      end

      # Records the properties skipped for a template.
      def add_skips(template_name, skips)
        @skips[template_name] = skips if skips.present?
      end

      # Records a failure message for a template.
      def add_failure(template_name, message)
        (@failures[template_name] ||= []) << message
      end

      # Marks a template's record as having had its life cycle stage set.
      def mark_life_cycle_set(template_name)
        @life_cycle_set << template_name
      end

      # Notes that a life cycle stage was requested but the feature is disabled.
      def note_life_cycle_disabled
        @life_cycle_disabled = true
      end

      # Number of records filled successfully.
      def created_count
        @successes.size
      end

      # Number of templates with at least one failure.
      def failed_count
        @failures.size
      end

      # Number of records whose life cycle stage was set.
      def life_cycle_set_count
        @life_cycle_set.size
      end

      # Human-readable summary with failures and skipped properties.
      def to_s
        lines = ["Test data generation: #{created_count} created, #{life_cycle_set_count} life-cycle-set, #{failed_count} failed."]
        lines << '  (life cycle feature disabled — stage not set)' if @life_cycle_disabled
        lines.concat(failure_lines)
        lines.concat(skip_lines)
        lines.join("\n")
      end

      private

      def failure_lines
        return [] if @failures.empty?

        ['', 'Failures:'] + @failures.map { |name, messages| "  - #{name}: #{messages.join(' | ')}" }
      end

      def skip_lines
        return [] if @skips.empty?

        total = @skips.values.sum(&:size)
        ['', "Skipped properties (#{total}):"] + @skips.map do |name, skips|
          "  - #{name}: " + skips.map { |s| "#{s[:property]} (#{s[:type]}: #{s[:reason]})" }.join(', ')
        end
      end
    end
  end
end
