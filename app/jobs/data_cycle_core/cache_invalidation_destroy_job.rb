# frozen_string_literal: true

module DataCycleCore
  class CacheInvalidationDestroyJob < UniqueApplicationJob
    queue_as :cache_invalidation
    queue_with_priority 10
    # args[3] is a thing_id list that can run into the thousands. Hashed rather than joined: the key
    # lands in the btree-indexed solid_queue_jobs.concurrency_key, which rejects an index row over
    # 2704 bytes — roughly 72 UUIDs — so joining them raises PG::ProgramLimitExceeded on enqueue.
    # Sorted before hashing so the key identifies the set rather than the row order: every caller but
    # ClassificationTreeLabel's batching plucks without an ORDER BY, so the same contents can arrive
    # in any order — two such enqueues must not look like two jobs.
    limits_concurrency key: ->(*args) { "#{args[2]}/#{args[1]}/#{Digest::SHA256.hexdigest(Array.wrap(args[3]).sort.join(','))}" }

    def perform(_class_name, _id, method_name, things_ids)
      send(method_name, things_ids)
    end

    private

    # This path carries the invalidation because no caller does:
    # ClassificationAlias#invalidate_things_cache hangs off after_update, and every path reaching
    # this one — a destroyed alias, a mapping delta, ClassificationTreeLabel's hidden-mapping
    # batches — enqueues update_things_search beside it and nothing else. A payload is cached under
    # the timestamps of the content it belongs to, which a classification change never moves, so the
    # re-export would ship what the receiver already has.
    def execute_things_webhooks_destroy(things_ids)
      return if things_ids.blank?

      DataCycleCore::Content::RelatedWebhooks.fan_out(DataCycleCore::Thing.where(id: things_ids), invalidate_related_cache: true)
    end

    def update_things_search(things_ids)
      return if things_ids.blank?

      DataCycleCore::Thing.where(id: things_ids).update_search_all
    end

    # Recomputes opted-in computed properties (compute.recompute_on_classification_change) for the
    # given contents, skipping the templates whose opted-in properties are bound to trees the
    # changed alias (arguments[1]) does not sit in.
    #
    # Which contents those are is the caller's choice, and the two kinds of change disagree. A mapping
    # delta passes the contents directly assigned the changed classification rather than the alias's
    # linked_contents: that is correct on removal (a content whose stored icon sits on an ancestor of
    # the removed leaf is still in this set and re-reads its full classifications) and far cheaper (no
    # transitive fan-out). A rename passes linked_contents, because a compute storing the concept's
    # name goes stale on everything hanging below it.
    def update_things_computed_properties(things_ids)
      return if things_ids.blank?

      tree_label = changed_alias&.classification_tree_label&.name
      computed_properties = DataCycleCore::ThingTemplate.classification_change_computed_properties_for(tree_label)
      return if computed_properties.blank?

      queue = DataCycleCore::WorkerPool.new

      DataCycleCore::Thing.where(id: things_ids, template_name: computed_properties.keys).find_each do |content|
        queue.append do
          content.update_computed_values(keys: computed_properties.dig(content.template_name, :computed_property_names))
        end
      end

      queue.wait!
    end

    # Rename/move variant: a compute storing the concept's name or reading its tree membership goes
    # stale on every content hanging below it, so the set is the alias's whole linked_contents — tens
    # of thousands on a broadly used concept. Resolved here rather than passed in, keeping the ids out
    # of the job arguments and out of the hashed concurrency key.
    def update_linked_things_computed_properties(_things_ids)
      return if changed_alias.nil?

      update_things_computed_properties(changed_alias.linked_contents.pluck(:id))
    end

    def changed_alias
      return @changed_alias if defined? @changed_alias

      @changed_alias = DataCycleCore::ClassificationAlias.find_by(id: arguments[1])
    end
  end
end
