# frozen_string_literal: true

module DataCycleCore
  # Whether this process still matches the database state it pinned itself to.
  #
  # A process derives two things from the database once and never refreshes them: the STI
  # subclasses Content::Extensions::TemplateModels::StiSubclasses generates from the
  # ThingTemplate rows, and Active Record's column information. A deploy runs db:migrate and
  # re-imports the templates from a one-off container while the old web container keeps
  # serving, so until `docker compose up -d` replaces it both are behind the database: a
  # dropped column arrives as PG::UndefinedColumn inside ActiveRecord::StatementInvalid, a
  # changed template as NoMethodError or SubclassNotFound from a subclass built off the
  # previous schema.
  #
  # #pin! runs where the STI init reads the templates, which is the first Thing instantiation
  # and not boot, so a model that loaded its column information earlier - users, from the first
  # sign-in - is outside what the pin covers.
  #
  # Only the error path asks, so a healthy request never pays for a query, and RECHECK_INTERVAL
  # keeps a crawler hammering one genuinely broken endpoint from turning every 500 into another
  # round trip. The verdict is monotonic - a template this process built a subclass from is
  # already const_set, so it cannot pick up a changed one - and the first `true` is final.
  module StaleProcess
    RETRY_AFTER = 30
    RECHECK_INTERVAL = 10

    # Both halves hash their whole input rather than take a maximum: MAX(version) misses a
    # migration merged in out of order, and thing_templates has no column that moves only on a
    # real change - TemplateImporter#update_templates writes `updated_at: Time.zone.now` for
    # every row on every run, so an import that changed nothing would mark every running
    # process stale until it is replaced.
    #
    # The templates half covers only the names #pin! was given. A template added since then is
    # not evidence: StiSubclasses#create_sti_subclass_for_type_if_missing! builds its subclass
    # on demand, so this process serves it as well as a fresh one would. A pinned name that
    # changed or disappeared drops out of the aggregate either way.
    FINGERPRINT_SQL = <<~SQL.squish
      SELECT
        (SELECT MD5(STRING_AGG(version, ',' ORDER BY version)) FROM schema_migrations) AS migrations,
        (SELECT MD5(STRING_AGG(template_name || COALESCE(schema::text, ''), '|' ORDER BY template_name))
          FROM thing_templates WHERE template_name = ANY (ARRAY[?]::VARCHAR[])) AS templates
    SQL

    class << self
      # Records the database state this process is about to generate its STI subclasses from.
      #
      # @param template_names [Array<String>] The names whose subclasses the caller is about to
      #   generate. An empty set still pins - a process holding no subclasses falls behind a
      #   migration just the same.
      # @return [void]
      def pin!(template_names)
        return if @fingerprint.present?

        # @fingerprint is published last and is the flag as well as the value, so a concurrent
        # stale? either sees a pin complete with the names it has to query, or no pin at all.
        @template_names = template_names
        @fingerprint = fingerprint_for(template_names)
      end

      # @return [Boolean] true once the database has moved past what #pin! recorded.
      def stale?
        return true if @stale
        return false if @fingerprint.blank?
        return false if @checked_at.present? && monotonic_now - @checked_at < RECHECK_INTERVAL

        @checked_at = monotonic_now
        fingerprint = fingerprint_for(@template_names)

        @stale = fingerprint.present? && fingerprint != @fingerprint
      end

      # @return [void]
      def reset!
        @fingerprint = nil
        @template_names = nil
        @stale = nil
        @checked_at = nil
      end

      private

      # @param template_names [Array<String>] Names the pin covers.
      # @return [Hash, nil] nil where the database cannot answer, which is not evidence of staleness.
      def fingerprint_for(template_names)
        ActiveRecord::Base.connection.select_one(
          ActiveRecord::Base.send(:sanitize_sql_array, [FINGERPRINT_SQL, template_names])
        )
      rescue StandardError
        nil
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
