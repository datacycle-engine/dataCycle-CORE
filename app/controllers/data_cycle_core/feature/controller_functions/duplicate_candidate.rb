# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateCandidate
        extend ActiveSupport::Concern

        def merge_with_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @split_source = DataCycleCore::Thing.find(Array.wrap(merge_params[:source_id]).first)
          @source_locale = source_params[:source_locale] || @split_source.first_available_locale
          authorize!(:merge_duplicates, @content)
          authorize!(:merge_duplicates, @split_source)

          redirect_back_or_to(root_path, alert: (I18n.t 'controllers.error.duplicate.cannot_merge_self', locale: helpers.active_ui_locale)) && return if @content.id == @split_source.id

          redirect_back_or_to(root_path, alert: (I18n.t 'controllers.error.duplicate.type_mismatch', locale: helpers.active_ui_locale)) && return if @content.template_name != @split_source.template_name

          # users allowed to merge but without edit permission only get a read-only preview
          @read_only = cannot?(:update, @content)

          I18n.with_locale(params[:locale] || @content.first_available_locale) do
            @locale = I18n.locale
            render && return
          end
        end

        def confirm_merge_with_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          # read-only merge: there is no preceding content save, so the merge itself writes the version
          return unless perform_merge(create_version: true)

          I18n.with_locale(@content.first_available_locale) do
            redirect_to(thing_path(@content, watch_list_id: @watch_list))
          end
        end

        def false_positive_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:source_id])
          authorize!(:merge_duplicates, @content)
          authorize!(:merge_duplicates, @duplicate)

          @content.mark_duplicate_as_false_positive(@duplicate)

          I18n.with_locale(@duplicate.first_available_locale) do
            redirect_back_or_to(root_path, notice: (I18n.t 'controllers.success.duplicate_false_positive', locale: helpers.active_ui_locale, data: @duplicate.try(:title)))
          end
        end

        def merge_and_remove_duplicate
          @duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])

          # editable path already wrote the version (with the copied-over values) in #update
          perform_merge(create_version: false)
        end

        def validate_duplicate
          @content = DataCycleCore::Thing.find(merge_params[:id])
          @duplicate = DataCycleCore::Thing.find(merge_params[:source_id])
          authorize!(:edit, @content)

          valid = { valid: true }

          valid[:warnings] = { duplicate_candidates: I18n.t('duplicate.merge_warning_html', locale: helpers.active_ui_locale) } if @content.external_source_id.present? && @duplicate.external_source_id.blank?

          render json: valid
        end

        private

        # shared merge for the editable (#merge_and_remove_duplicate) and read-only
        # (#confirm_merge_with_duplicate) paths. authorizes both sides, validates the pair
        # and performs the merge. returns false (after redirecting) when a guard fails.
        # create_version: whether this method writes the named version documenting the merge.
        # The read-only path passes true (no preceding save); the editable path passes false
        # because #update already wrote the version together with the copied-over values.
        def perform_merge(create_version:) # rubocop:disable Naming/PredicateMethod
          authorize!(:merge_duplicates, @content)
          authorize!(:merge_duplicates, @duplicate)

          if @content.id == @duplicate.id
            redirect_back_or_to(root_path, alert: (I18n.t 'controllers.error.duplicate.cannot_merge_self', locale: helpers.active_ui_locale))
            return false
          end

          if @content.template_name != @duplicate.template_name
            redirect_back_or_to(root_path, alert: (I18n.t 'controllers.error.duplicate.type_mismatch', locale: helpers.active_ui_locale))
            return false
          end

          # the version has to be written before the merge, so that a merge failing part way
          # through is still recorded on the original
          @content.create_merge_version(@duplicate, current_user:) if create_version

          if DataCycleCore::Feature::DuplicateCandidate.merge_inline?(@duplicate)
            merge_inline
          else
            merge_in_background
          end

          true
        end

        # merges within the request, so the duplicate is gone when the page reloads
        def merge_inline
          @content.merge_with_duplicate(@duplicate, current_user:, async: false)

          flash[:success] = I18n.t('controllers.success.merged_with_duplicate', locale: helpers.active_ui_locale)
        rescue StandardError => e
          # an inline merge can fail part way through (e.g. locked contents). merging is
          # idempotent => the job merges whatever is left over, but the user has to know
          # that the merge is not done yet.
          merge_in_background(e)
        end

        # hands the merge to MergeDuplicateJob and hides the pair in the meantime
        def merge_in_background(error = nil)
          @content.merge_with_duplicate(@duplicate, current_user:, async: true)

          if error.nil?
            flash[:success] = I18n.t('controllers.success.merged_with_duplicate_background', locale: helpers.active_ui_locale)
            return
          end

          ActiveSupport::Notifications.instrument 'duplicate_merge_failed.datacycle', {
            exception: error,
            step_label: "merge duplicate into #{@content.id}",
            item_id: @duplicate.id
          }

          # the editable path saved the content before merging (ContentsController#update) and
          # already reported that as a success => drop it, so the error is the only verdict on
          # the merge. warnings from the save (flash[:info]) stay, they describe the content.
          flash.delete(:success)
          flash[:error] = I18n.t('controllers.error.duplicate.merge_failed', locale: helpers.active_ui_locale)
        end

        def merge_params
          params.permit(:id, :source_id, :duplicate_id, source_id: [])
        end

        def version_name_for_merge(datahash)
          duplicate = DataCycleCore::Thing.find(merge_params[:duplicate_id])
          version_name = DataCycleCore::Feature::DuplicateCandidate.version_name_for_merge(duplicate, helpers.active_ui_locale)

          datahash[:version_name] = [
            datahash[:version_name],
            version_name
          ].compact_blank.join(' / ')
        end
      end
    end
  end
end
