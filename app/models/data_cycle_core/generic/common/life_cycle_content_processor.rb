# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # Shared plumbing for the per-external-system life-cycle import strategies ArchiveContents and
      # ReactivateContents. Both bulk-load their (differently scoped) download items via
      # ImportFunctions.import_bulk, resolve the matching Things in one query, and update them across a
      # WorkerPool.
      #
      # Bring the helpers in with +extend+; the including strategy has to define +.load_contents+ and
      # +.process_content+ (which +import_data+ wires up as iterator and data processor).
      module LifeCycleContentProcessor
        # Forces a full import and dispatches to the bulk driver (whole set handed to #process_content).
        # The life-cycle stage is stored as a (language-independent) classification on the Thing, so running
        # one pass per locale would resolve and re-touch every Thing redundantly. Restrict the run to the
        # primary (first configured) locale.
        def import_data(utility_object:, options:)
          utility_object.mode = :full
          utility_object.locales = utility_object.locales.first(1)

          DataCycleCore::Generic::Common::ImportFunctions.import_bulk(
            utility_object:,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        # Resolves, in a single query, the Things for a set of raw download items (optional
        # +external_key_prefix+ + value at +external_key_path+), scoped to the current external source.
        # When the step configures +template_name+(s) the query is narrowed to them (as DeleteContentsSafe
        # does), so a Thing of a different template that happens to share an external key is left alone.
        def find_contents(utility_object:, raw_data:, locale:, options:)
          external_key_path = options.dig(:import, :external_key_path)
          raise ArgumentError, "#{name} requires the 'external_key_path' import option" if external_key_path.blank?

          external_key_path = external_key_path.split('.')
          external_keys = raw_data.filter_map { |item| item.dump[locale]&.dig(*external_key_path) }
          external_keys.map! { |key| [options.dig(:import, :external_key_prefix), key].join } if options.dig(:import, :external_key_prefix)

          contents = DataCycleCore::Thing.where(
            external_source_id: utility_object.external_source.id,
            external_key: external_keys
          )

          template_names = Array.wrap(options.dig(:import, :template_name))
          template_names.present? ? contents.where(template_name: template_names) : contents
        end

        # Primes the class-level, per-life-cycle-configuration ordered-classifications memo
        # (Feature::LifeCycle.ordered_classifications) on the main thread before work is handed to the
        # WorkerPool below, so its threads hit a warm cache instead of racing to run the same query on a
        # cold one. The contents of a single step share a template (one life-cycle configuration), so
        # touching the first content warms the entry they all read.
        def warm_life_cycle_classifications(contents)
          content = contents.first
          DataCycleCore::Feature::LifeCycle.ordered_classifications(content) if content
        end

        # Runs the given block for every content across a WorkerPool (parallel outside tests, each job on
        # its own DB connection) and returns the count of contents for which the block returned a truthy value.
        def update_in_parallel(contents)
          queue = DataCycleCore::WorkerPool.new
          updated = Concurrent::AtomicFixnum.new(0)

          contents.find_each do |content|
            queue.append { updated.increment if yield(content) }
          end

          queue.wait!
          updated.value
        end
      end
    end
  end
end
