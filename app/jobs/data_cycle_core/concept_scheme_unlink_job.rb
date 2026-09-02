# frozen_string_literal: true

module DataCycleCore
  class ConceptSchemeUnlinkJob < UniqueApplicationJob
    include DataCycleCore::ClassificationHelper

    KEY = 'unlink'
    METHOD_NAME = :remove_concepts_by_scheme
    LINK_TYPE = 'direct'

    queue_with_priority 10
    # by the time the first run of a scheme/collection pair finishes there is nothing left for a
    # second one to unlink, so a duplicate is dropped rather than queued behind it — which is what
    # the delayed_job era did by aborting the enqueue for any non-failed job of the same reference
    limits_concurrency key: ->(*args) { "#{args[0]}/#{args[1]}" }, on_conflict: :discard

    # runs after abort_if_queued, so a discarded duplicate leaves the in-flight run's state alone
    before_enqueue { |job| Rails.cache.delete(job.class.state_cache_key(*job.arguments.first(2))) }

    def self.stream_name(concept_scheme_id, collection_id)
      DataCycleCore::ConceptSchemeLinkChannel.stream_name(key: self::KEY, collection_id:, concept_scheme_id:)
    end

    def self.state_cache_key(concept_scheme_id, collection_id)
      DataCycleCore::ConceptSchemeLinkChannel.state_cache_key(stream_name(concept_scheme_id, collection_id))
    end

    def perform(concept_scheme_id, collection_id, current_user_id)
      @concept_scheme_id = concept_scheme_id
      @collection_id = collection_id
      collection = DataCycleCore::Collection.find(collection_id)
      concept_scheme = DataCycleCore::ConceptScheme.find(concept_scheme_id)
      current_user = DataCycleCore::User.find(current_user_id)
      things = collection.things.reorder(nil)
      things_size = things.size
      count = concept_scheme_ccc_count(concept_scheme, collection, self.class::LINK_TYPE)
      valid = true
      error = nil
      last_progress = 0

      broadcast(progress: 0)

      things.find_each.with_index(1) do |thing, index|
        progress = ((index.to_f / things_size) * 100).round
        valid_thing = thing.send(self.class::METHOD_NAME, concept_scheme:, current_user:)

        if valid_thing.is_a?(FalseClass)
          error = thing.errors.full_messages.join(', ')
          valid = false
        end
      ensure
        # one message per whole percent, not per thing: the socket has to survive the whole run, and a
        # large collection otherwise floods it with thousands of messages carrying 101 distinct values
        if progress != last_progress
          last_progress = progress
          broadcast(progress:)
        end
      end

      broadcast(
        finished: true,
        result: [
          {
            concept_scheme_name: concept_scheme.name,
            collection_name: collection.name,
            count: count,
            valid:,
            error:
          }
        ]
      )
    rescue StandardError => e
      broadcast(error: e.message)
    end

    private

    # mirrored into the cache so a client that reconnects mid-run can have the channel replay the
    # latest state — see ConceptSchemeLinkChannel#resync
    def broadcast(payload)
      payload = { collection_id: @collection_id, concept_scheme_id: @concept_scheme_id }.merge(payload)

      Rails.cache.write(self.class.state_cache_key(@concept_scheme_id, @collection_id), payload, expires_in: 1.day)
      ActionCable.server.broadcast(self.class.stream_name(@concept_scheme_id, @collection_id), payload)
    end
  end
end
