# frozen_string_literal: true

module DataCycleCore
  class DashBoardController < ApplicationController
    authorize_resource class: false # from cancancan (authorize)

    def home
      @errors = nil
      @duplicates = nil
      @stat_database = StatsDatabase.new(current_user.id)
      @stat_job_queue = StatsJobQueue.new.update
    end

    def download
      @external_source = ExternalSystem.find(params[:id])
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download', delayed_reference_id: @external_source.id, locked_at: nil, failed_at: nil)
        flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: helpers.active_ui_locale
      else
        DownloadJob.perform_later(@external_source.id)
        flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale
      end
      redirect_to admin_path
    end

    def import
      @external_source = ExternalSystem.find(params[:id])
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'import', delayed_reference_id: @external_source.id, locked_at: nil, failed_at: nil)
        flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: helpers.active_ui_locale
      else
        ImportOnlyJob.perform_later(@external_source.id)
        flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale
      end
      redirect_to admin_path
    end

    def import_full
      @external_source = ExternalSystem.find(params[:id])
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'import_full', delayed_reference_id: @external_source.id, locked_at: nil, failed_at: nil)
        flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: helpers.active_ui_locale
      else
        ImportFullJob.perform_later(@external_source.id)
        flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale
      end
      redirect_to admin_path
    end

    def download_full
      @external_source = ExternalSystem.find(params[:id])
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download_full', delayed_reference_id: @external_source.id, locked_at: nil, failed_at: nil)
        flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: helpers.active_ui_locale
      else
        DownloadFullJob.perform_later(@external_source.id)
        flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale
      end
      redirect_to admin_path
    end

    def download_import
      @external_source = ExternalSystem.find(params[:id])
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download_import', delayed_reference_id: @external_source.id, locked_at: nil, failed_at: nil)
        flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: helpers.active_ui_locale
      else
        ImportJob.perform_later(@external_source.id)
        flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: helpers.active_ui_locale
      end
      redirect_to admin_path
    end

    def delete_queue
      job = Delayed::Job.find(params[:id])
      job.destroy if job.present?
      redirect_to admin_path
    end

    def import_templates
      @errors = nil
      @duplicates = nil
      errors, duplicates = DataCycleCore::MasterData::ImportTemplates.import_all
      if errors.blank? && duplicates.blank?
        flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'data types', locale: helpers.active_ui_locale
      else
        error_level = errors.blank? ? :notice : :error
        @errors = errors
        @duplicates = duplicates
        puts 'duplicates:'
        ap duplicates
        puts 'errors:'
        ap errors
        flash[error_level] = "errors/warnings were encountered: ##{errors.count} / ##{duplicates.count}"
      end
      redirect_to admin_path
    end

    def import_classifications
      MasterData::ImportClassifications.import_all
      flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'basic classification trees', locale: helpers.active_ui_locale
      redirect_to admin_path
    end

    def import_external_systems
      @errors = nil
      errors = MasterData::ImportExternalSystems.import_all
      if errors.blank?
        flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'import external systems', locale: helpers.active_ui_locale
      else
        @errors = errors
        puts 'errors:'
        ap errors
        flash[:error] = I18n.t('dash_board.errors_were_encountered', locale: helpers.active_ui_locale)
      end
      redirect_to admin_path
    end

    def classifications
    end

    def activities
    end

    def activity_details
      type = permitted_params.dig(:type)
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
      @permitted_params ||= params.permit(*permitted_parameter_keys).reject { |_, v| v.blank? }
    end

    def permitted_parameter_keys
      [:type]
    end
  end
end
