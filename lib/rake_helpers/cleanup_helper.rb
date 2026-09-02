# frozen_string_literal: true

class CleanupHelper
  class << self
    def identify_external_source(item)
      return nil if item.config.blank?

      item.config['download_config'].first[1]['endpoint'].split('::')[-2]
    end

    def linked(external_source)
      core_data_templates = {
        'Booking' => ['Unterkunft'],
        'EventDatabase' => ['Event'],
        'Feratel' => ['Event', 'POI', 'Unterkunft'],
        'MediaArchive' => ['Bild', 'Video'],
        'OutdoorActive' => ['POI', 'Tour'],
        'VTicket' => ['Event'],
        'Xamoom' => ['Örtlichkeit']
      }[external_source]
      return if core_data_templates.blank?

      core_data_templates&.map { |template|
        thing_template = DataCycleCore::Thing.new(template_name: template)
        thing_template.linked_property_names.map do |linked_item|
          properties = thing_template.properties_for(linked_item)
          if properties['template_name'].present?
            { relation: linked_item, template: properties['template_name'] }
          elsif properties['stored_filter'].present?
            properties['stored_filter'].first.dig('with_classification_aliases_and_treename', 'aliases').map do |item|
              { relation: linked_item, template: item }
            end
          end
        end
      }&.flatten&.uniq
    end

    def embedded
      embedded_hash = {}
      DataCycleCore::ThingTemplate.where(content_type: 'entity').map do |main_thing_temp|
        main_temp = DataCycleCore::Thing.new(thing_template: main_thing_temp)
        main_temp.embedded_property_names.map do |embedded_item|
          properties = main_temp.properties_for(embedded_item)
          if embedded_hash.key?(properties['template_name'])
            embedded_hash[properties['template_name']].push(main_temp.template_name)
          else
            embedded_hash[properties['template_name']] = [main_temp.template_name]
          end
        end
      end
      embedded_hash.map { |key, value| { key => value.uniq } }.reduce({}, &:merge)
    end

    def orphaned_embedded(template_array, embedded_name)
      template_string = "'#{template_array.join("', '")}'"
      where_string = <<~SQL.squish
        things.id NOT IN (
          SELECT things.id FROM things
          INNER JOIN content_contents ON content_contents.content_b_id = things.id
          INNER JOIN things things2 ON content_contents.content_a_id = things2.id
          WHERE things.template_name = '#{embedded_name}'
          AND things2.template_name IN (#{template_string})
        )
      SQL

      DataCycleCore::Thing.where(template_name: embedded_name).where(ActiveRecord::Base.send(:sanitize_sql_for_conditions, where_string))
    end

    # Whether the record was delivered inside the grace period. Only the primary external_key is
    # considered: external_hashes has a foreign key onto things (external_source_id, external_key),
    # so a key merged in from a duplicate never has a row of its own - the importer bails out before
    # writing one once the key resolves to a content with a different primary key.
    RECENTLY_SEEN_SQL = <<~SQL.squish
      EXISTS (
        SELECT 1 FROM external_hashes
        WHERE external_hashes.external_source_id = things.external_source_id
          AND external_hashes.external_key = things.external_key
          AND external_hashes.seen_at > :cutoff
      )
    SQL

    # Imported contents in `scope` that have no incoming link left and have not been delivered for
    # at least `min_age_days` days (see dc:clean_up:archive_orphans, #37010).
    #
    # The missing link is the actual criterion, not the missing delivery. A merged record keeps the
    # primary key of whichever record survived, so once that one's source retires it looks
    # undelivered even though sibling keys still arrive and still link to it — the link check is
    # what protects it. The age check is only a grace period against transient import states, and a
    # record without any external_hashes row has no delivery to fall inside it, so for those the
    # grace period is a no-op.
    #
    # @param scope [ActiveRecord::Relation] things to consider, usually a stored filter's things
    # @param min_age_days [Integer] days a record has to have gone undelivered
    # @return [ActiveRecord::Relation]
    def orphaned_imported(scope, min_age_days:)
      scope
        .where.not(external_source_id: nil)
        .where.missing(:content_content_b)
        .where.not(ActiveRecord::Base.send(:sanitize_sql_array, [RECENTLY_SEEN_SQL, { cutoff: min_age_days.to_i.days.ago }]))
    end

    # Contents in `scope` that have an incoming link again - the counterpart of #orphaned_imported,
    # used to bring a previously archived record back once a new delivery re-links it.
    #
    # @param scope [ActiveRecord::Relation] things to consider
    # @return [ActiveRecord::Relation]
    def reattached(scope)
      scope.where.associated(:content_content_b).distinct
    end

    # Life-cycle-archives every not-yet-archived content in `relation`.
    #
    # @return [Integer] number of contents archived
    def archive_contents!(relation, logger: nil)
      update_life_cycle_in_batches(relation, logger:) do |content|
        next false if content.try(:archived?)

        content.archive
      end
    end

    # Moves archived contents in `relation` back to an active life-cycle stage ("feed wins"),
    # mirroring DataCycleCore::Generic::Common::ReactivateContents.
    #
    # @param stage_name [String, nil] target stage, blank falls back to the stage configured for the
    #   content (see DataCycleCore::Feature::LifeCycle.active_name)
    # @return [Integer] number of contents reactivated
    def reactivate_contents!(relation, stage_name: nil, logger: nil)
      update_life_cycle_in_batches(relation, logger:) do |content|
        next false unless content.try(:archived?)

        content.reactivate(nil, stage_name:)
      end
    end

    # Builds the StoredFilter `parameters` for the per-template orphan cleanup (see
    # dc:clean_up:orphans_by_template, #42950). Pure function of already-resolved ids so it can be
    # unit tested. Parameter keys: c=combine (a=and), m=mode (i=include/e=exclude/n=none/neutral),
    # n=label/filter method, t=filter type, v=value.
    #
    # The template restriction is always present (it also guards the delete step). The two optional
    # modes are independent; passing both AND-combines them:
    #   exclude_source_ids: nil            -> excludes mode not applied
    #                       [] or [ids...] -> only imported content (with_external_source), minus the
    #                                         given external systems ([] excludes nothing = ALL systems)
    #   base_filter_ids:    [ids...]       -> only content that is in ANY of the referenced stored
    #                                         filters (filter_ids builds a UNION of them)
    def orphan_filter_parameters(template_name:, exclude_source_ids: nil, base_filter_ids: nil)
      parameters = [
        { 'c' => 'a', 'm' => 'i', 'n' => 'Inhaltstyp', 't' => 'template_names', 'v' => [template_name] }
      ]

      unless exclude_source_ids.nil?
        # The "imported content" filter is a boolean filter: t='boolean' dispatches to the method
        # named in n (with_external_source) – see DataCycleCore::Filter::Search#boolean.
        parameters << { 'c' => 'a', 'm' => 'n', 'n' => 'with_external_source', 't' => 'boolean', 'v' => 'true' }
        parameters << { 'c' => 'a', 'm' => 'e', 'n' => 'Externe Systeme (ausgenommen)', 't' => 'external_source', 'v' => exclude_source_ids }
      end

      parameters << { 'c' => 'a', 'm' => 'i', 'n' => 'Basis-Filter', 't' => 'filter_ids', 'v' => base_filter_ids } if base_filter_ids.present?

      parameters
    end

    # Runs the block, retrying when PostgreSQL aborts the transaction with a
    # deadlock (PG::TRDeadlockDetected, wrapped by ActiveRecord::Deadlocked) or a
    # lock-wait timeout. When orphans are destroyed concurrently (see the WorkerPool
    # in dc:clean_up:external_data) the transactions touch overlapping rows for
    # heavily shared content like "Bild" (shared classifications, embedded asset/
    # rights, cascade index maintenance) and can grab locks in inconsistent order,
    # so PostgreSQL kills one of them to break the cycle. The victim's work has been
    # rolled back cleanly (destroy_content runs in its own transaction), so simply
    # running it again usually succeeds. A short, growing, jittered back-off
    # desynchronizes the competing workers. Returns true on success, false when the
    # block keeps deadlocking after max_tries (logged, so the caller can keep going).
    def with_deadlock_retry(logger: nil, identifier: nil, max_tries: 5)
      tries = 0

      begin
        tries += 1
        yield
        true
      rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout => e
        if tries < max_tries
          logger&.warn("[deadlock] retrying #{identifier} (#{tries}/#{max_tries}): #{e.class}")
          sleep((0.05 * tries) + (rand * 0.1))
          retry
        end

        logger&.error("[deadlock] giving up on #{identifier} after #{max_tries} tries: #{e.class} - #{e.message}")
        false
      end
    end

    private

    # Runs the life-cycle transition in the block for every content of `relation` across a
    # WorkerPool and returns how often it reported a change. Contents whose template has no
    # life-cycle configuration are skipped, so a mixed relation is safe to pass.
    #
    # Feature::LifeCycle.ordered_classifications is primed on the main thread first: it memoizes
    # per life-cycle configuration, and a cold memo would have every worker race to run the same
    # query (same reasoning as Generic::Common::LifeCycleContentProcessor#warm_life_cycle_classifications).
    #
    # @return [Integer] number of contents changed
    def update_life_cycle_in_batches(relation, logger: nil)
      DataCycleCore::Feature::LifeCycle.ordered_classifications(relation.first)
      changed = Concurrent::AtomicFixnum.new(0)

      relation.find_in_batches(batch_size: 1000) do |batch|
        # WorkerPool#wait! shuts the underlying thread pool down, so each batch needs a fresh one
        # (reusing it raises Concurrent::RejectedExecutionError).
        queue = DataCycleCore::WorkerPool.new

        batch.each do |content|
          queue.append do
            next unless DataCycleCore::Feature::LifeCycle.allowed?(content)

            with_deadlock_retry(logger:, identifier: "Thing #{content.id}") do
              changed.increment if yield(content)
            end
          end
        end

        queue.wait!
      end

      changed.value
    end
  end
end
