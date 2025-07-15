# frozen_string_literal: true

module DataCycleCore
  class ConceptSchemeLinkChannel < ApplicationCable::Channel
    def subscribed
      reject && return if current_user.blank?
      stream_from "concept_scheme_#{params[:key]}_#{params[:collection_id]}_#{params[:concept_scheme_id]}"
    end

    def unsubscribed
    end
  end
end
