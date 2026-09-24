# frozen_string_literal: true

module DataCycleCore
  class ConceptSchemeLinkChannel < ApplicationCable::Channel
    def self.stream_name(key:, collection_id:, concept_scheme_id:)
      "concept_scheme_#{key}_#{collection_id}_#{concept_scheme_id}"
    end

    def self.state_cache_key(stream_name)
      "#{stream_name}/state"
    end

    def subscribed
      concept_scheme = DataCycleCore::ConceptScheme.find_by(id: params[:concept_scheme_id])
      reject && return unless concept_scheme
      reject && return unless current_user&.can?(:link_contents, concept_scheme) ||
                              current_user&.can?(:unlink_contents, concept_scheme)

      @stream_name = self.class.stream_name(
        key: params[:key],
        collection_id: params[:collection_id],
        concept_scheme_id: concept_scheme.id
      )

      stream_from @stream_name
    end

    # Called by the client once ActionCable has transparently reconnected it. Broadcasts sent while the
    # socket was down are gone, so without this a run that finished during the gap never reports back.
    def resync
      return if @stream_name.blank?

      state = Rails.cache.read(self.class.state_cache_key(@stream_name))

      transmit(state) if state
    end

    def unsubscribed
    end
  end
end
