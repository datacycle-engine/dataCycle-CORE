# frozen_string_literal: true

module DataCycleCore
  # Checks that the queues jobs are enqueued to are actually served by a worker.
  #
  # +DataCycleCore.job_queues+ names the queues core knows about, but which of them a deployment
  # runs is decided by its own +config/queue.yml+ — a template that every project keeps its own copy
  # of, and that the dashboard never reads. A queue missing there is the quietest kind of
  # misconfiguration there is: the enqueue succeeds, the dashboard shows the job as queued in a
  # queue it considers known, and nothing ever picks it up.
  class JobQueueValidation
    # Queue names that stand for every queue, as +SolidQueue::QueueSelector+ reads them.
    WILDCARDS = ['*', '**'].freeze

    # Queues that are meant to have no worker outside of staging and production: exports must not
    # fire at a developer's whim, and +dc:sync:trigger_webhooks+ runs them synchronously when they
    # are actually wanted. Deliberate, and documented in config/queue.yml.template.
    UNSERVED_LOCALLY = [:webhooks].freeze

    # @param configuration [SolidQueue::Configuration] defaults to the app's own config/queue.yml
    # @param config_file [Pathname, nil] the file that configuration came from, nil to not look
    def initialize(configuration = SolidQueue::Configuration.new, config_file: Rails.root.join(SolidQueue::Configuration::DEFAULT_CONFIG_FILE_PATH))
      @configuration = configuration
      @config_file = config_file
    end

    # @return [Array<String>] one message per misconfiguration, empty when there is none
    def errors
      missing_config_file + unserved_queues + external_systems_on_unknown_queues
    end

    # Queue names the workers of this configuration claim from, wildcards included.
    # @return [Array<String>]
    def configured_queues
      @configured_queues ||= configuration.configured_processes
        .select { |process| process.kind == :worker }
        .flat_map { |process| Array.wrap(process.attributes[:queues]) }
        .flat_map { |queues| queues.to_s.split(',') }
        .map(&:strip)
        .compact_blank
        .uniq
    end

    # @param queue [String, Symbol]
    # @return [Boolean] whether any configured worker would run a job enqueued to that queue
    def served?(queue)
      configured_queues.any? do |configured|
        next true if configured.in?(WILDCARDS)
        next queue.to_s.start_with?(configured.delete_suffix('*')) if configured.end_with?('*')

        configured == queue.to_s
      end
    end

    private

    attr_reader :configuration, :config_file

    # Without the file SolidQueue runs its own defaults — a single worker on every queue, three
    # threads — which serves every queue and so passes the check below while silently dropping both
    # the serial +importers+ worker and the per-queue isolation the template sets up.
    def missing_config_file
      return [] if config_file.nil? || File.exist?(config_file)

      ["#{config_file} is missing, so SolidQueue falls back to one worker for all queues: run rails dc:upgrade:copy_templates[global]"]
    end

    def unserved_queues
      expected_queues.reject { |queue| served?(queue) }.map do |queue|
        "no worker in config/queue.yml claims from the '#{queue}' queue"
      end
    end

    def expected_queues
      DataCycleCore.job_queues.keys - (Rails.env.local? ? UNSERVED_LOCALLY : [])
    end

    # The contract rejects these at config time, but default_options is a jsonb column that can be
    # written without going through it — and ExternalSystem#import_queue then quietly falls back.
    def external_systems_on_unknown_queues
      return [] unless external_systems_readable?

      DataCycleCore::ExternalSystem.where("default_options ->> 'queue' IS NOT NULL").filter_map do |external_system|
        queue = external_system[:default_options]['queue']
        next if queue.to_sym.in?(DataCycleCore.importer_queues)

        "external system '#{external_system.name}' is configured for the unknown import queue '#{queue}', falling back to 'importers'"
      end
    end

    # Every other check here reads the checkout, and +dc:validate+ is run over one that has no
    # database at all: that is what CI validates before it ever creates one, and what a project does
    # before its first migration. Leaves this check without anything to look at rather than with
    # something to report.
    def external_systems_readable?
      DataCycleCore::ExternalSystem.table_exists?
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      false
    end
  end
end
