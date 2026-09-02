# frozen_string_literal: true

module DataCycleCore
  class DashBoardController < ApplicationController
    authorize_resource class: false # from cancancan (authorize)

    def home
      @errors = nil
      @duplicates = nil
      @stat_database = StatsDatabase.new.load_all_stats
      @stats_job_queue = StatsJobQueue.new.job_list
      @rebuilding_classification_mappings = SolidQueue::Job.live.exists?(class_name: DataCycleCore::RebuildClassificationMappingsJob.name)
      @grouped_external_systems = DataCycleCore::ExternalSystem.grouped_by_type(@stat_database.import_modules)
    end

    def pg_stats
      @stat_database = StatsDatabase.new.load_pg_stats
    end

    def download
      enqueue_import_job(DownloadJob)
    end

    def import
      enqueue_import_job(ImportOnlyJob)
    end

    def download_import
      enqueue_import_job(ImportJob)
    end

    def delete_queue
      job = SolidQueue::Job.find_by(id: import_params[:id])

      # A claimed job is being executed right now and must not be destroyed: `before_destroy
      # :unblock_next_blocked_job` only fires while the job is ready, and ClaimedExecution#finalize
      # will not release the lock either once its row is gone — so the semaphore would stay taken
      # until it expires (15 minutes for imports), with the orphaned run still extending it. The view
      # already hides the button for a running job; this catches the stale page. No message needed,
      # the response re-renders the queue and shows why nothing happened.
      job.destroy unless job.nil? || job.claimed?

      respond_to_admin_path_actions
    end

    def rebuild_classification_mappings
      DataCycleCore::RebuildClassificationMappingsJob.perform_later

      respond_to do |format|
        format.html { redirect_to(admin_path, notice: I18n.t('dash_board.maintenance.classification_mappings.queued', locale: helpers.active_ui_locale)) }
        format.turbo_stream do
          flash.now[:success] = I18n.t('dash_board.maintenance.classification_mappings.queued', locale: helpers.active_ui_locale)
          render turbo_stream: [
            turbo_stream.append(:'flash-messages', partial: 'data_cycle_core/shared/flash'),
            turbo_stream.replace(
              :admin_dashboard_concept_mapping_job,
              method: :morph,
              partial: 'data_cycle_core/dash_board/concept_mappings_button',
              locals: { rebuilding: true }
            ),
            *job_queue_streams
          ]
        end
      end
    end

    def computed_attributes_form
    end

    def update_computed_attributes
      computed_names = Array.wrap(update_computed_attributes_params[:computed_name]).compact_blank
      scope = update_computed_attributes_params[:templates_or_collection_id].presence

      if computed_names.blank? || scope.blank?
        message = I18n.t('dash_board.maintenance.computed_attributes.missing_input', locale: helpers.active_ui_locale)

        respond_to do |format|
          format.html { redirect_to(admin_path, alert: message) }
          format.turbo_stream do
            flash.now[:error] = message
            render turbo_stream: turbo_stream.append(:'flash-messages', partial: 'data_cycle_core/shared/flash')
          end
        end
      else
        webhooks = ActiveModel::Type::Boolean.new.cast(update_computed_attributes_params[:webhooks]).present?
        DataCycleCore::RunTaskJob.perform_later('dc:update_data:computed_attributes', [scope, webhooks, computed_names.join('|')])
        message = I18n.t('dash_board.maintenance.computed_attributes.queued', locale: helpers.active_ui_locale)

        respond_to do |format|
          format.html { redirect_to(admin_path, notice: message) }
          format.turbo_stream do
            flash.now[:success] = message
            render turbo_stream: [
              turbo_stream.append(:'flash-messages', partial: 'data_cycle_core/shared/flash'),
              *job_queue_streams
            ]
          end
        end
      end
    end

    def import_module
      @external_source_id = import_module_partial_params[:id]
      @data = DataCycleCore::StatsDatabase.new.load_mongo_stats(@external_source_id)
    end

    def activities
    end

    def activity_details
      type = permitted_params[:type]
      case type
      when 'summary'
        activities = DataCycleCore::Activity.activity_stats
      when 'user_summary'
        activities = DataCycleCore::Activity.activities_user_overview
      when 'details'
        activities = DataCycleCore::Activity.activity_details
      else
        render(json: { error: I18n.t('controllers.error.unknown_activity_type', locale: helpers.active_ui_locale) }) && return
      end
      render json: { data: activities&.as_json&.map { |activity| activity.except('id') } }
    end

    private

    def update_computed_attributes_params
      @update_computed_attributes_params ||= params.permit(:templates_or_collection_id, :webhooks, computed_name: [])
    end

    # queues +job_class+ for the requested external system, unless an identical job is already pending
    def enqueue_import_job(job_class)
      @external_source = ExternalSystem.find(import_params[:id])
      job = job_class.new(@external_source.id, import_params[:mode])

      if job.duplicate_queued_with_args?
        flash[:info] = I18n.t('controllers.job.running', locale: helpers.active_ui_locale)
      else
        job.enqueue
        flash[:success] = I18n.t('controllers.job.added', data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale)
      end

      respond_to_admin_path_actions
    end

    # the pair of turbo-stream updates that refreshes the dashboard job queue panel
    def job_queue_streams
      stat_job_queue = DataCycleCore::StatsJobQueue.new.job_list

      [
        turbo_stream.update(:jobs_queue_title, partial: 'data_cycle_core/dash_board/job_queue_title', locals: { stat_job_queue: }),
        turbo_stream.update(:jobs_queue_body, partial: 'data_cycle_core/dash_board/job_queue_body', locals: { stat_job_queue: })
      ]
    end

    def respond_to_admin_path_actions
      respond_to do |format|
        format.html { redirect_to admin_path }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append(:'flash-messages', partial: 'data_cycle_core/shared/flash', locals: { flash: flash.discard }),
            *job_queue_streams
          ]
        end
      end
    end

    def import_module_partial_params
      params.permit(:id)
    end

    def permitted_params
      @permitted_params ||= params.permit(*permitted_parameter_keys).compact_blank
    end

    def permitted_parameter_keys
      [:type]
    end

    def import_params
      params.permit(:id, :mode)
    end
  end
end
