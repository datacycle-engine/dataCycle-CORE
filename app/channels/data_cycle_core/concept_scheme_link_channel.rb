# frozen_string_literal: true

module DataCycleCore
  class ConceptSchemeLinkChannel < ApplicationCable::Channel
    def subscribed
      concept_scheme = DataCycleCore::ConceptScheme.find_by(id: params[:concept_scheme_id])
      reject && return unless concept_scheme
      reject && return unless current_user&.can?(:link_contents, concept_scheme) ||
                              current_user&.can?(:unlink_contents, concept_scheme)

      stream_from "concept_scheme_#{params[:key]}_#{params[:collection_id]}_#{concept_scheme.id}"
    end

    def unsubscribed
    end
  end
end
