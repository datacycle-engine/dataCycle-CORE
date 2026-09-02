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
        @collection = nil
      end

      # Describes a collection by everything that tells a right one from a wrong one: path, id, owner,
      # and whether it is served to API consumers. Public and on the class so a caller can name the
      # collection it is about to write into before the run, not only read it back out afterwards.
      #
      # @return [String, nil] nil when there is no collection to describe.
      def self.describe_collection(collection)
        return if collection.nil?

        traits = [collection.user_id.nil? ? 'system-owned' : "owned by user #{collection.user_id}"]
        traits << 'api' if collection.api?
        traits << 'my selection' if collection.my_selection?

        "#{collection.full_path} (#{collection.id}, #{traits.join(', ')})"
      end

      # Records the collection the run adds its records to. Reported because collection_id reaches
      # any collection in the installation, so a wrong-but-existing id is indistinguishable from a
      # correct one in the counts and the generator cannot take the records back out again. Described
      # on the way in rather than held as a record: a rolled-back run (DRY_RUN) resets the id of a
      # collection created inside its transaction, and that report is worth reading too.
      def note_collection(collection)
        @collection = self.class.describe_collection(collection)
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
        lines << collection_line
        lines << '  (life cycle feature disabled — stage not set)' if @life_cycle_disabled
        lines.concat(failure_lines)
        lines.concat(skip_lines)
        lines.join("\n")
      end

      private

      def collection_line
        "  Collection: #{@collection || 'none — the records are not collected'}"
      end

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
