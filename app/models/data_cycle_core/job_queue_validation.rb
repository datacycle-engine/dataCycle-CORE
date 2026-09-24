# frozen_string_literal: true

module DataCycleCore
  # Checks that the queues jobs are enqueued to are actually served by a worker.
  #
  # +DataCycleCore.job_queues+ names the queues core knows about, but which of them a deployment
  # runs is decided by its own +config/queue.yml+, a copy of a template that the dashboard never
  # reads. A queue missing there fails quietly: the enqueue succeeds, the dashboard shows the job as
  # queued in a queue it considers known, and nothing ever picks it up.
  class JobQueueValidation
    # Queue names that stand for every queue, as +SolidQueue::QueueSelector+ reads them.
    WILDCARDS = ['*', '**'].freeze

    # Queues that are meant to have no worker outside of staging and production: exports must not
    # fire at a developer's whim, and +dc:sync:trigger_webhooks+ runs them synchronously when they
    # are actually wanted. Deliberate, and documented in config/queue.yml.template.
    UNSERVED_LOCALLY = [:webhooks].freeze

    # Queues whose jobs call +Process.fork+: per page in +Generic::Common::ImportFunctions+, per run
    # in +ClassificationMappingJob+, per batch of things in +Feature::CustomAssetPreviewer+, and
    # anywhere +dc:update_data:*+ reaches, since +RunTaskJob+ runs whichever rake task it was handed.
    # A child inherits the mutexes its parent's other threads held at the moment of the fork, so a
    # worker serving one of these must run one job at a time and take its concurrency from
    # +processes+ instead. +DataCycleCore.importer_queues+ lists two of the same names for an
    # unrelated reason, so a project that appends an import queue there adds one this check misses.
    FORKING_QUEUES = [:importers, :importers_short, :default].freeze

    # The two +Rails.env.local?+ names, whose config/queue.yml section +multithreaded_forking_queues+
    # leaves alone: the queues share one threaded worker there because a developer machine is not
    # worth four booted Rails.
    LOCAL_ENVIRONMENTS = [:development, :test].freeze

    # The keys SolidQueue reads processes from (+Configuration#processes_config+), and so what marks
    # a value in config/queue.yml as a section of its own rather than one section's contents: a
    # +scheduler:+ block is a Hash as much as an environment is, and a flat file's +workers:+ is an
    # Array.
    PROCESS_KEYS = [:workers, :dispatchers, :scheduler].freeze

    # @param configuration [SolidQueue::Configuration] defaults to the app's own config/queue.yml
    # @param config_file [Pathname, nil] the file that configuration came from — the default names
    #   it the way +SolidQueue::Configuration+ does, so both halves read one file even where
    #   SOLID_QUEUE_CONFIG points somewhere else; nil to not look
    def initialize(configuration = SolidQueue::Configuration.new, config_file: Rails.root.join(ENV['SOLID_QUEUE_CONFIG'] || SolidQueue::Configuration::DEFAULT_CONFIG_FILE_PATH))
      @configuration = configuration
      @config_file = config_file
    end

    # @return [Array<String>] one message per misconfiguration, empty when there is none
    def errors
      unconfigured_deployment + unserved_queues + multithreaded_forking_queues + external_systems_on_unknown_queues
    end

    # Queue names the workers of this configuration claim from, wildcards included.
    # @return [Array<String>]
    def configured_queues
      @configured_queues ||= worker_processes.flat_map { |process| queues_of(process) }.uniq
    end

    # @param queue [String, Symbol]
    # @return [Boolean] whether any configured worker would run a job enqueued to that queue
    def served?(queue)
      configured_queues.any? { |configured| claims?(configured, queue) }
    end

    private

    attr_reader :configuration, :config_file

    # @return [Array<SolidQueue::Configuration::Process>]
    def worker_processes
      @worker_processes ||= workers_of(configuration)
    end

    # @param config [SolidQueue::Configuration]
    # @return [Array<SolidQueue::Configuration::Process>] one entry per process a worker is given
    def workers_of(config)
      config.configured_processes.select { |process| process.kind == :worker }
    end

    # @param process [SolidQueue::Configuration::Process]
    # @return [Array<String>] the queue names one worker claims from, wildcards included
    def queues_of(process)
      Array.wrap(process.attributes[:queues])
        .flat_map { |queues| queues.to_s.split(',') }
        .map(&:strip)
        .compact_blank
    end

    # Whether one entry of a worker's +queues+ list covers the given queue. Wildcards and prefixes
    # count, which is why +multithreaded_forking_queues+ asks through here rather than by name: a
    # worker on '*' serves the forking queues without ever naming one.
    # @param configured [String] one entry as config/queue.yml spells it
    # @param queue [String, Symbol]
    # @return [Boolean]
    def claims?(configured, queue)
      return true if configured.in?(WILDCARDS)
      return queue.to_s.start_with?(configured.delete_suffix('*')) if configured.end_with?('*')

      configured == queue.to_s
    end

    # A deployment that finds no section of its own runs SolidQueue's defaults, one worker of three
    # threads on every queue, which passes the check below while dropping both the serial +importers+
    # worker and the per-queue isolation the template sets up. Three files get there: an absent one,
    # one that names only the local sections, and one that names other deployed environments but not
    # this one.
    #
    # The message names dc:upgrade rather than copy_templates[global] alone, because the third file
    # is the one a project reaches for review: the template carries no review: section, and what
    # resolves it is clean_configs removing the config/environments/review.rb core no longer ships.
    def unconfigured_deployment
      return [] if config_file.nil?

      unconfigured = deployed_sections.select { |_environment, section| section.nil? }.keys
      return [] if unconfigured.empty?

      reason = File.exist?(config_file) ? "has no section for #{unconfigured.join('/')}" : 'is missing'

      ["#{config_file_name} #{reason}, so SolidQueue falls back to one worker for all queues: run rails dc:upgrade"]
    end

    # Reads the booted configuration, whereas +multithreaded_forking_queues+ reads the deployed
    # sections: a queue no worker claims at all is a mistake in the anchor block every environment
    # shares, and +UNSERVED_LOCALLY+ is how a queue meant for a deployment alone is spelled. What
    # this does not reach is a queue dropped from the deployed section while the anchor block still
    # serves it in test.
    def unserved_queues
      expected_queues.reject { |queue| served?(queue) }.map do |queue|
        "no worker in #{config_file_name} claims from the '#{queue}' queue"
      end
    end

    # Reads the sections that run the invariant rather than the booted environment: CI validates
    # under RAILS_ENV=test, where the workers in hand are the shared threaded one
    # +LOCAL_ENVIRONMENTS+ keeps on purpose, whatever the staging and production blocks say.
    # @return [Array<String>] one message per worker, however many sections and processes it spans
    def multithreaded_forking_queues
      deployed_worker_processes.filter_map { |process| multithreaded_forking_error(process) }.uniq
    end

    # What runs the jobs is +fibers+ where a worker names them and +threads+ otherwise, the pair
    # SolidQueue's own +worker_capacity+ reads in that order: +worker_defaults_for+ leaves +threads+
    # out of a fiber worker's attributes entirely, so reading it alone counts a worker of 3 fibers as
    # one job at a time.
    # @param process [SolidQueue::Configuration::Process]
    # @return [String, nil] nil for a worker that runs one job at a time or claims nothing forking
    def multithreaded_forking_error(process)
      unit = process.attributes.key?(:fibers) ? :fibers : :threads
      concurrency = process.attributes[unit].to_i
      return if concurrency <= 1

      claimed = queues_of(process)
      forking = FORKING_QUEUES.select { |queue| claimed.any? { |configured| claims?(configured, queue) } }
      return if forking.empty?

      "the worker claiming '#{claimed.join(', ')}' in #{config_file_name} runs #{concurrency} #{unit}; #{forking.join(', ')} fork, so give it #{unit}: 1 and raise processes instead"
    end

    # The workers of every deployed section, or those of the configuration itself when there is no
    # file to read. +only_work+ keeps each list from also instantiating the dispatchers and recurring
    # tasks this check discards: a +SolidQueue::RecurringTask+ is an Active Record model, and
    # +dc:validate+ runs where +external_systems_readable?+ answers false.
    # @return [Array<SolidQueue::Configuration::Process>]
    def deployed_worker_processes
      return worker_processes if config_file.nil?

      deployed_sections.values.compact.uniq.filter_map { |section| section[:workers].presence }
        .flat_map { |workers| workers_of(SolidQueue::Configuration.new(workers:, only_work: true)) }
    end

    # Resolved one environment at a time the way +Configuration#config_from+ resolves the one it
    # runs, because an environment the file names no section for is the case that matters: SolidQueue
    # answers that one with WORKER_DEFAULTS, the wildcard worker of three threads over the queues
    # that fork. Pooling the sections instead let one configured deployment answer for the rest.
    #
    # Sections are read merged, so one that takes its +workers+ from the anchor block is checked
    # against the list it actually runs. An empty body (`production:` and nothing under it) reads as
    # an absent key does, and a file that names no environment resolves to itself for every one of
    # them, both on the falsiness +config_from+ turns on too.
    # @return [Hash{Symbol => Hash, nil}] the section each deployed environment runs, nil for one
    #   left to SolidQueue's fallback worker
    def deployed_sections
      @deployed_sections ||= deployed_environments.index_with do |environment|
        [queue_file_sections[environment], queue_file_sections].find { |value| process_section?(value) }
      end
    end

    # Named from config/environments rather than by excluding the local sections: which environments
    # a project has differs (some ship staging and production, some production alone), and a section
    # that names none of them is not one SolidQueue ever loads.
    # Subtracting instead takes the template's `default: &default` anchor for a deployed section as
    # soon as a project renames it, and reports the anchor's shared worker against a deployment that
    # overrides it. Sorted, so a message naming several does not follow the filesystem's glob order.
    # @return [Array<Symbol>]
    def deployed_environments
      @deployed_environments ||= (Rails.root.glob('config/environments/*.rb').map { |path| path.basename('.rb').to_s.to_sym } - LOCAL_ENVIRONMENTS).sort
    end

    # @param value [Object] one value of config/queue.yml's top level
    # @return [Boolean] whether it is a section carrying processes of its own
    def process_section?(value)
      value.is_a?(Hash) && PROCESS_KEYS.any? { |key| value.key?(key) }
    end

    # @return [String] the file the messages point at, named the way SolidQueue names it where there
    #   is no file in hand (+config_file: nil+, which checks a workers list on its own)
    def config_file_name
      (config_file || SolidQueue::Configuration::DEFAULT_CONFIG_FILE_PATH).to_s
    end

    # @return [Hash] every section of config/queue.yml, read the way SolidQueue reads the one it runs
    def queue_file_sections
      return {} unless config_file && File.exist?(config_file)

      @queue_file_sections ||= ActiveSupport::ConfigurationFile.parse(config_file).deep_symbolize_keys
    end

    def expected_queues
      DataCycleCore.job_queues - (Rails.env.local? ? UNSERVED_LOCALLY : [])
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
