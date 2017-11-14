module DataCycleCore
  class DashBoardController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    authorize_resource :class => false         # from cancancan (authorize)

    def home
      @statOutdoorActive = StatsDatabase.new(current_user.id)
      @statJobQueue = StatsJobQueue.new.update
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
      errors = {}
      path = Rails.root.join('config','data_definitions','creative_works','*.yml')
      error = MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::CreativeWork)
      errors.merge!({ creative_works: error}) unless error.blank?
      path = Rails.root.join('config','data_definitions','places','*.yml')
      error = MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Place)
      errors.merge!({ places: error}) unless error.blank?
      path = Rails.root.join('config','data_definitions','persons','*.yml')
      error = MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Person)
      errors.merge!({ persons: error}) unless error.blank?
      path = Rails.root.join('config','data_definitions','events','*.yml')
      error = MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Event)
      errors.merge!({events: error}) unless error.blank?
      if errors.blank?
        flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: "data types", locale: DataCycleCore.ui_language
      else
        ap errors
        flash[:error] = "the following errors were encountered: #{errors}"
      end
      redirect_to admin_path
    end

    def import_classifications
      path = Rails.root.join('config','data_definitions','classifications.yml')
      MasterData::ImportClassifications.new.import(path.to_s)
      flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: "basic classification trees", locale: DataCycleCore.ui_language
      redirect_to admin_path
    end

    def classifications
    end

    def logs
      @dataname = params[:dataname]
    end

  end
end
