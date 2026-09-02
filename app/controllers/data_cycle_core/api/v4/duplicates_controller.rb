# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      # Reads and manages the duplicate candidates of a content: list them, mark a pair manually,
      # merge a pair and dismiss a pair as a false positive. Mirrors the backend duplicate handling
      # (Feature::ControllerFunctions::DuplicateCandidate) for API clients like the duplicate review
      # tool, and reuses its +merge_duplicates+ ability.
      #
      # Both contents of a pair have to be inside the caller's api scope (authorize_api_content!),
      # and the listing hides candidates outside of it: +@id+ is freely chosen by the caller, so
      # without that check the endpoints would report the name of any content of the same template and
      # attach a manual pair to it. Only the validity part of the scope is bypassed, so expired
      # contents stay reachable (see ApiBaseController#build_api_scope_query).
      class DuplicatesController < ApiBaseController
        VALIDATE_PARAMS_CONTRACT = MasterData::Contracts::ApiDuplicatesContract

        # score of a pair a user marked explicitly - the maximum a detection module can reach as well,
        # which is why the paging needs the @id tiebreaker next to the score
        MANUAL_SCORE = 100

        before_action :prepare_url_parameters
        before_action :duplicate_candidates_enabled!
        before_action :set_content
        before_action :set_duplicate, except: [:index]

        # Lists the candidates, one entry per duplicate content, highest score first.
        def index
          render_duplicates
        end

        # Marks the pair as duplicates explicitly, next to any automatically detected candidates
        # (the unique index covers thing_ids + method). Idempotent, and reactivates a pair that was
        # previously dismissed as a false positive.
        def create
          already_marked = manual_candidate.present?

          reactivate_pair
          create_manual_candidate unless already_marked

          render_duplicates(status: already_marked ? :ok : :created)
        end

        # Hands the merge to MergeDuplicateJob and hides the pair right away, so the answer does not
        # depend on how many linked contents the merge has to move.
        def merge
          @content.merge_with_duplicate_and_version(@duplicate, current_user:, async: true)

          render_duplicates(status: :accepted)
        end

        # Dismisses the pair: it disappears from the candidates and is not re-added by the automatic
        # recalculation.
        def false_positive
          @content.mark_duplicate_as_false_positive(@duplicate)

          render_duplicates
        end

        private

        def duplicate_candidates_enabled!
          raise ActiveRecord::RecordNotFound unless DataCycleCore::Feature::DuplicateCandidate.enabled?
        end

        # Embedded contents are rejected before the api scope is consulted: they can never have
        # duplicates - automatic detection skips them (Feature::DataHash::DuplicateCandidate
        # #after_save_data_hash returns early for embedded contents) - and the api scope excludes them
        # anyway, so asking it first would answer a content that has no business here with 401 instead
        # of the reason.
        def set_content
          @content = DataCycleCore::Thing.find(permitted_params[:id])

          authorize! :merge_duplicates, @content

          return render_embedded_error if @content.embedded?

          authorize_api_content!(@content, skip_validity: true)
        end

        # Resolves the other half of the pair - from the body for #create, from the route for the
        # actions that address an existing pair - and rejects pairs that can never be duplicates.
        def set_duplicate
          duplicate_id = permitted_params[:duplicate_id].presence || permitted_params[:@id].presence

          return render_api_error(:bad_request, '@id is required') if duplicate_id.blank?

          @duplicate = DataCycleCore::Thing.find(duplicate_id)

          authorize! :merge_duplicates, @duplicate

          return render_embedded_error if @duplicate.embedded?

          authorize_api_content!(@duplicate, skip_validity: true)

          return render_api_error(:unprocessable_content, 'a content cannot be a duplicate of itself') if @duplicate.id == @content.id

          render_api_error(:unprocessable_content, "template mismatch: #{@content.template_name} != #{@duplicate.template_name}") if @duplicate.template_name != @content.template_name
        end

        def render_embedded_error
          render_api_error(:unprocessable_content, 'embedded contents cannot be duplicates')
        end

        def create_manual_candidate
          DataCycleCore::ThingDuplicate.create!(
            thing_id: @content.id,
            thing_duplicate_id: @duplicate.id,
            method: DataCycleCore::Utility::DuplicateCandidate::Manual.identifier,
            score: MANUAL_SCORE
          )
        rescue ActiveRecord::RecordNotUnique
          # concurrent request marked the very same pair: the desired state is reached
        end

        # Marking a pair as a false positive flags every row of it, so reactivating has to clear
        # every row of it again - including the automatically detected ones.
        def reactivate_pair
          pair_candidates.update_all(false_positive: false)
        end

        def manual_candidate
          pair_candidates.find_by(method: DataCycleCore::Utility::DuplicateCandidate::Manual.identifier)
        end

        # Both rows of the pair, in whichever direction they were stored.
        def pair_candidates
          ids = [@content.id, @duplicate.id]

          DataCycleCore::ThingDuplicate.where(thing_id: ids, thing_duplicate_id: ids)
        end

        # Read through the schema the request was validated against, not coerced a second time by hand:
        # Dry reads +no+ and +n+ as false, ActiveModel::Type::Boolean does not know them and would list
        # the dismissed pairs for a request that validated as "the active ones".
        def false_positive_mode?
          MasterData::Contracts::ApiDuplicatesContract::DUPLICATE_PARAMS.call(permitted_params.to_h).to_h[:falsePositive].present?
        end

        # +meta+ is skipped for section[meta]=0, which saves the count query - the way apply_paging
        # answers it with a countless kaminari page for every other list response.
        def render_duplicates(status: :ok)
          body = { '@id' => @content.id }
          body['meta'] = duplicates_meta unless section_settings[:meta].to_i.zero?
          body['dc:duplicates'] = duplicate_entries

          render json: body, status:
        end

        def duplicates_meta
          total = @content.duplicate_candidates_count_for_api(false_positive: false_positive_mode?, visible_scope: api_visible_scope)

          { 'total' => total, 'pages' => (total.to_f / page_size).ceil }
        end

        def duplicate_entries
          @content.duplicate_candidates_for_api(
            false_positive: false_positive_mode?,
            languages: @language,
            limit: page_size,
            offset: page_offset,
            visible_scope: api_visible_scope
          )
        end

        # The things the caller may see, as a relation to restrict the candidates with, or nil when the
        # caller has no api scope at all.
        # @return [ActiveRecord::Relation, nil]
        def api_visible_scope
          api_scope_query(skip_validity: true)
        end

        def page_settings
          @page_settings ||= DEFAULT_PAGE_SETTINGS.merge(page_parameters)
        end

        def section_settings
          @section_settings ||= DEFAULT_SECTION_SETTINGS.merge(section_parameters)
        end

        # page[limit]/page[offset] take precedence over page[size]/page[number], the way
        # ApiBaseController#apply_paging treats them for every other list response.
        def page_size
          limit = page_settings[:limit].to_i

          return limit if limit.positive?

          size = page_settings[:size].to_i
          size.positive? ? size : DEFAULT_PAGE_SETTINGS[:size]
        end

        # Without page[limit] the offset is added on top of the page, the way apply_paging hands it to
        # kaminari as padding.
        def page_offset
          offset = page_settings[:offset].to_i

          return offset if page_settings[:limit].to_i.positive?

          (([page_settings[:number].to_i, 1].max - 1) * page_size) + offset
        end

        def permitted_parameter_keys
          super + [:id, :duplicate_id, :falsePositive, :@id]
        end
      end
    end
  end
end
