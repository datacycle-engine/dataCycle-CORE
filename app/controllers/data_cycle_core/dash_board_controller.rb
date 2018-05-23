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

    def download
      @uuid = params[:uuid]
      DownloadJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.name
      flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: name, uuid: @uuid, locale: DataCycleCore.ui_language
      redirect_to admin_path
    end

    def import
      @uuid = params[:uuid]
      ImportJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.name
      flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: name, uuid: @uuid, locale: DataCycleCore.ui_language
      redirect_to admin_path
    end

    def import_templates
      @errors = nil
      @duplicates = nil
      error = nil
      duplicates = nil
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
      path = Rails.root.join('config', 'data_definitions', 'classifications.yml')
      MasterData::ImportClassifications.import(path.to_s)
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

    def classifications
    end

    def logs
      @dataname = params[:dataname]
    end
  end
end
