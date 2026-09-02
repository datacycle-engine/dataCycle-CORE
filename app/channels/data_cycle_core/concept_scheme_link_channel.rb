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
      # the ability is declared on ClassificationTreeLabel — which is also what the button's can? checks
      # — so authorizing the ConceptScheme matched no rule and rejected every role without a blanket one
      tree_label = concept_scheme&.classification_tree_label
      reject && return unless tree_label
      reject && return unless current_user&.can?(:link_contents, tree_label) ||
                              current_user&.can?(:unlink_contents, tree_label)

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
