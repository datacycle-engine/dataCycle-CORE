# frozen_string_literal: true

module DataCycleCore
  class ConceptSchemeUnlinkJob < ApplicationJob
    include DataCycleCore::ClassificationHelper

    PRIORITY = 10
    KEY = 'unlink'
    METHOD_NAME = :remove_concepts_by_scheme
    LINK_TYPE = 'direct'

    before_enqueue :check_for_existing_jobs

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      "#{self.class.name.demodulize}##{arguments[1]}"
    end

    def perform(concept_scheme_id, collection_id, current_user_id)
      channel_name = "concept_scheme_#{self.class::KEY}_#{collection_id}_#{concept_scheme_id}"
      collection = DataCycleCore::Collection.find(collection_id)
      concept_scheme = DataCycleCore::ConceptScheme.find(concept_scheme_id)
      current_user = DataCycleCore::User.find(current_user_id)
      things = collection.things.reorder(nil)
      things_size = things.size
      count = concept_scheme_ccc_count(concept_scheme, collection, self.class::LINK_TYPE)
      valid = true
      error = nil

      ActionCable.server.broadcast(channel_name, { collection_id:, concept_scheme_id:, progress: 0 })

      things.find_each.with_index(1) do |thing, index|
        valid_thing = thing.send(self.class::METHOD_NAME, concept_scheme:, current_user:)

        if valid_thing.is_a?(FalseClass)
          error = thing.errors.full_messages.join(', ')
          valid = false
        end

        progress = ((index.to_f / things_size) * 100).round
      ensure
        ActionCable.server.broadcast(channel_name, { collection_id:, concept_scheme_id:, progress:})
      end

      ActionCable.server.broadcast(channel_name, {
        collection_id:,
        concept_scheme_id:,
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
      })
    rescue StandardError => e
      ActionCable.server.broadcast(channel_name, { collection_id:, concept_scheme_id:, error: e.message })
    end

    private

    def check_for_existing_jobs
      throw :abort if Delayed::Job.exists?(
        queue: queue_name,
        delayed_reference_id:,
        delayed_reference_type:,
        failed_at: nil
      )
    end
  end
end
