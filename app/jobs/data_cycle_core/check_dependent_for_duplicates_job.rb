# frozen_string_literal: true

module DataCycleCore
  class CheckDependentForDuplicatesJob < UniqueApplicationJob
    queue_as :search_update
    queue_with_priority 6
    limits_concurrency key: ->(*args) { args[0] }

    def perform(id, _changed_attributes)
      return unless Feature::DuplicateCandidate.enabled?

      id_attribute_hash = ContentContent::Link.id_attribute_hash(id)
      return if id_attribute_hash.blank?

      check_relevant_things(id_attribute_hash)
    end

    private

    def check_relevant_things(attribute_hash)
      queue = WorkerPool.new

      Thing.where(id: attribute_hash.keys).find_each do |t|
        queue.append { check_thing(t, attribute_hash[t.id]) }
      end

      queue.wait!
    end

    def check_thing(thing, attributes)
      return if attributes.blank? ||
                thing.embedded? ||
                !thing.duplicate_candidates_allowed? ||
                !thing.affected_by_change?(attributes)

      thing.create_duplicate_candidates
    end
  end
end
