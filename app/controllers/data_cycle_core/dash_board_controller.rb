# frozen_string_literal: true

module DataCycleCore
  class DashBoardController < ApplicationController
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def home
      @errors = nil
      @duplicates = nil
      @stat_outdoor_active = StatsDatabase.new(current_user.id)
      @stat_job_queue = StatsJobQueue.new.update
    end

    # def download
    #   @uuid = params[:uuid]
    #   if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'download', delayed_reference_id: @uuid, locked_at: nil)
    #     flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: DataCycleCore.ui_language
    #   else
    #     DownloadJob.perform_later(@uuid)
    #     name = ExternalSource.where(id: @uuid).first.name
    #     flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: name, uuid: @uuid, locale: DataCycleCore.ui_language
    #   end
    #   redirect_to admin_path
    # end

    def import
      @external_source = ExternalSource.find(params[:id])
      if Delayed::Job.exists?(queue: 'importers', delayed_reference_type: 'import', delayed_reference_id: @external_source.id, locked_at: nil)
        flash[:notice] = I18n.t :running, scope: [:controllers, :job], locale: DataCycleCore.ui_language
      else
        ImportJob.perform_later(@external_source.id)
        flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: @external_source.name, uuid: @external_source.id, locale: DataCycleCore.ui_language
      end
      redirect_to admin_path
    end

    def import_templates
      @errors = nil
      @duplicates = nil
      errors, duplicates = DataCycleCore::MasterData::ImportTemplates.import_all
      if errors.blank? && duplicates.blank?
        flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'data types', locale: DataCycleCore.ui_language
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
      flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'basic classification trees', locale: DataCycleCore.ui_language
      redirect_to admin_path
    end

    def import_config
      @errors = nil
      errors = MasterData::ImportExternalSources.import_all
      if errors.blank?
        flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'import configs', locale: DataCycleCore.ui_language
      else
        @errors = errors
        puts 'errors:'
        ap errors
        flash[:error] = 'errors were encountered'
      end
      redirect_to admin_path
    end

    def import_external_systems
      @errors = nil
      errors = MasterData::ImportExternalSystems.import_all
      if errors.blank?
        flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: 'import external systems', locale: DataCycleCore.ui_language
      else
        @errors = errors
        puts 'errors:'
        ap errors
        flash[:error] = 'errors were encountered'
      end
      redirect_to admin_path
    end

    def classifications
    end

    def logs
      @dataname = params[:dataname]
    end
  end
end
