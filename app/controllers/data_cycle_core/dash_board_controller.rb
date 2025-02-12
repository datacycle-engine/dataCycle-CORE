# frozen_string_literal: true

module DataCycleCore
  class DashBoardController < ApplicationController
    authorize_resource class: false # from cancancan (authorize)

    def home
      @errors = nil
      @duplicates = nil
      @stat_database = StatsDatabase.new.load_all_stats
      @stat_job_queue = StatsJobQueue.new.job_list
      @grouped_external_systems = DataCycleCore::ExternalSystem.grouped_by_type(@stat_database.import_modules)
    end

    def download
      @external_source = ExternalSystem.find(import_params[:id])
      job = DownloadJob.new(@external_source.id, import_params[:mode])

      if Delayed::Job.exists?(queue: job.queue_name, delayed_reference_type: job.delayed_reference_type, delayed_reference_id: job.delayed_reference_id, locked_at: nil, failed_at: nil)
        flash[:info] = I18n.t(:running, scope: [:controllers, :job], locale: helpers.active_ui_locale)
      else
        job.enqueue
        flash[:success] = I18n.t(:added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale)
      end

      redirect_to admin_path
    end

    def import
      @external_source = ExternalSystem.find(import_params[:id])
      job = ImportOnlyJob.new(@external_source.id, import_params[:mode])

      if Delayed::Job.exists?(queue: job.queue_name, delayed_reference_type: job.delayed_reference_type, delayed_reference_id: job.delayed_reference_id, locked_at: nil, failed_at: nil)
        flash[:info] = I18n.t(:running, scope: [:controllers, :job], locale: helpers.active_ui_locale)
      else
        job.enqueue
        flash[:success] = I18n.t(:added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale)
      end

      redirect_to admin_path
    end

    def download_import
      @external_source = ExternalSystem.find(import_params[:id])
      job = ImportJob.new(@external_source.id, import_params[:mode])

      if Delayed::Job.exists?(queue: job.queue_name, delayed_reference_type: job.delayed_reference_type, delayed_reference_id: job.delayed_reference_id, locked_at: nil, failed_at: nil)
        flash[:info] = I18n.t(:running, scope: [:controllers, :job], locale: helpers.active_ui_locale)
      else
        job.enqueue
        flash[:success] = I18n.t(:added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale)
      end

      redirect_to admin_path
    end

    def delete_queue
      job = Delayed::Job.find(import_params[:id])
      job.destroy if job.present?
      redirect_to admin_path
    end

    def rebuild_classification_mappings
      DataCycleCore::RebuildClassificationMappingsJob.perform_later

      respond_to do |format|
        format.html { redirect_to(admin_path, notice: I18n.t('dash_board.maintenance.classification_mappings.queued', locale: helpers.active_ui_locale)) }
        format.json { head :ok }
      end
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
        render(json: { error: I18n.t(:unknown_activity_type, scope: [:controllers, :error], locale: helpers.active_ui_locale) }) && return
      end
      render json: { data: activities&.as_json&.map { |activity| activity.except('id') } }
    end

    def logs
      @dataname = params[:dataname]
    end

    private

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
