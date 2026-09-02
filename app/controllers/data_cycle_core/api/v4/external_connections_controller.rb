# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      # Manages a content's external connections (external_system_syncs with sync_type +duplicate+)
      # and its primary external system over the API, mirroring the backend UI actions
      # (ExternalConnectionsConcern, ContentsController#create_external_connection). The same
      # abilities gate both, so a role's rights apply identically in UI and API.
      #
      # A connection is addressed by +propertyID+ (external system identifier, name or uuid) plus
      # +value+ (external key) — the pair the API already exposes as +identifier+ PropertyValues —
      # so no internal sync id has to be published. +create+ and +destroy+ are idempotent.
      #
      # Not to be confused with +PATCH /api/v4/external_sources/:external_source_id/demote+, which
      # lets an importing system bulk-demote *its own* contents via its configured api_strategy.
      class ExternalConnectionsController < ApiBaseController
        VALIDATE_PARAMS_CONTRACT = MasterData::Contracts::ApiExternalConnectionsContract

        # the backend ability each action reuses, so a role's rights apply identically in UI and API
        ACTION_ABILITIES = {
          'create' => :create_external_connection,
          'destroy' => :remove_external_connection,
          'promote' => :switch_primary_external_system,
          'demote' => :demote_primary_external_system
        }.freeze

        before_action :prepare_url_parameters
        before_action :set_content
        before_action :set_connection_target, except: [:demote]

        # Adds the addressed connection as a +duplicate+ sync. Idempotent: an already existing
        # connection is left untouched and still answered with the current state.
        def create
          return render_primary_connection_error if primary_connection?
          return render_managed_connection_error if managed_sync.present?

          # invalidate_self is a FOR UPDATE SKIP LOCKED bulk update over the content and everything
          # caching it, so it only runs when a connection was actually added
          begin
            sync = @content.external_system_syncs.find_or_create_by!(
              external_system_id: @external_system.id,
              external_key: @external_key,
              sync_type: ExternalSystemSync::SYNC_TYPES[:duplicate]
            )

            @content.invalidate_self if sync.previously_new_record?
          rescue ActiveRecord::RecordNotUnique
            # concurrent request created the very same connection: the desired state is reached
          end

          render_connections
        end

        # Removes the addressed +duplicate+ connection. Idempotent: nothing to remove is a success,
        # so a retried request after a lost response does not report an error.
        def destroy
          return render_primary_connection_error if primary_connection?

          sync = matching_sync(ExternalSystemSync::SYNC_TYPES[:duplicate])

          return render_managed_connection_error if sync.nil? && managed_sync.present?

          if sync.present?
            sync.destroy
            @content.invalidate_self
          end

          render_connections
        end

        # Makes the addressed connection the content's primary external system. Only +duplicate+ and
        # +import+ syncs can be promoted, mirroring the backend UI.
        def promote
          return render_primary_connection_error if primary_connection?

          sync = matching_sync(ExternalSystemSync::SYNC_TYPES.values_at(:duplicate, :import))

          raise ActiveRecord::RecordNotFound if sync.nil?

          # keeps the previous primary system as a duplicate connection
          @content.switch_primary_external_system(sync)

          render_connections
        rescue ActiveRecord::RecordNotUnique
          # another content already holds this key as its primary one (unique index on
          # things.external_source_id + external_key). Rescued here rather than left to
          # ErrorHandler: its RecordNotUnique => :conflict mapping is shadowed for
          # ActionController::API by the later `StatementInvalid => :bad_request` handler.
          render_api_error(:conflict, 'another content already uses this external key as its primary external system')
        end

        # Turns the content's primary external system into a +duplicate+ connection, so the external
        # key is preserved while the content is no longer owned by that system.
        def demote
          return render_missing_primary_error if @content.external_source_id.blank?

          @content.external_source_to_external_system_syncs(ExternalSystemSync::SYNC_TYPES[:duplicate])

          render_connections
        end

        private

        # Authorizes here rather than in the actions so the check runs before set_connection_target:
        # otherwise a caller without the ability could tell an unknown external system (404) from an
        # existing one (401) and enumerate the configured systems.
        #
        # The caller's api scope is enforced on top of the ability, so a token cannot write to contents
        # outside of it. Only its validity part is bypassed, so an expired content stays connectable
        # (see ApiBaseController#api_scope_query).
        #
        # Embedded contents are deliberately *not* excluded: imports give them external keys of their
        # own (a primary system as well as +duplicate+ connections), and the backend lets all four
        # actions run on them - ExternalConnectionsConcern checks no content_type. Excluding them here
        # would take away functionality the UI has instead of correcting anything.
        def set_content
          @content = DataCycleCore::Thing.find(permitted_params[:id])

          authorize! ACTION_ABILITIES.fetch(action_name), @content
          authorize_api_content!(@content, skip_validity: true)
        end

        # +by_names_identifiers_or_ids+ matches identifier, name and uuid, and none of them is unique
        # in the schema - prefer an exact identifier match and order the remainder, so a collision
        # between one system's name and another's identifier does not resolve by row order.
        def set_connection_target
          @external_key = permitted_params[:value]
          property_id = permitted_params[:propertyID]

          return render_api_error(:bad_request, 'propertyID and value are required') if property_id.blank? || @external_key.blank?

          @external_system = DataCycleCore::ExternalSystem
            .by_names_identifiers_or_ids(property_id)
            .min_by { |system| [system.identifier == property_id ? 0 : 1, system.identifier.to_s] }

          raise ActiveRecord::RecordNotFound if @external_system.nil?
        end

        # The syncs of this content matching the addressed external system and key, optionally
        # narrowed to given sync types.
        # @param sync_types [String, Array<String>, nil] sync types to restrict the lookup to
        # @return [DataCycleCore::ExternalSystemSync, nil]
        def matching_sync(sync_types = nil)
          syncs = @content.external_system_syncs.where(external_system_id: @external_system.id, external_key: @external_key)
          syncs = syncs.where(sync_type: sync_types) if sync_types.present?

          syncs.first
        end

        # A sync for the addressed pair that belongs to the import resp. the export machinery. Such a
        # connection is neither removable nor may a +duplicate+ one be added next to it - that would
        # list the same propertyID/value pair twice in +identifier+, with different valueReferences.
        # @return [DataCycleCore::ExternalSystemSync, nil]
        def managed_sync
          matching_sync(ExternalSystemSync::SYNC_TYPES.values_at(:import, :export))
        end

        def primary_connection?
          @content.external_source_id == @external_system.id && @content.external_key == @external_key
        end

        # The content's connections after the change, so a client does not need a second request.
        def render_connections
          @content.reload

          render json: { '@id' => @content.id, 'identifier' => @content.external_syncs_as_property_values }
        end

        def render_primary_connection_error
          render_api_error(:unprocessable_content, 'the addressed connection is the primary external system of this content, use the demote endpoint instead')
        end

        def render_managed_connection_error
          render_api_error(:unprocessable_content, 'the addressed connection is managed by an import or export and cannot be changed here')
        end

        def render_missing_primary_error
          render_api_error(:unprocessable_content, 'this content has no primary external system to demote')
        end

        def permitted_parameter_keys
          super + [:id, :propertyID, :value]
        end
      end
    end
  end
end
