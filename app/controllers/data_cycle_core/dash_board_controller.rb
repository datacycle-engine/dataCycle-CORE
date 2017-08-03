module DataCycleCore
  class DashBoardController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def home
      @statOutdoorActive = StatsDatabase.new(current_user.id)
      @statJobQueue = StatsJobQueue.new.update
    end

    def download
      @uuid = params[:uuid]
      DownloadJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.name
      flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: name, uuid: @uuid
      redirect_to admin_path
    end

    def import
      @uuid = params[:uuid]
      ImportJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.name
      flash[:notice] = I18n.t :added, scope: [:controllers, :job], data: name, uuid: @uuid
      redirect_to admin_path
    end

    def import_templates
      path = Rails.root.join('config','data_definitions','creative_works','*.yml')
      MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::CreativeWork)
      path = Rails.root.join('config','data_definitions','places','*.yml')
      MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Place)
      path = Rails.root.join('config','data_definitions','persons','*.yml')
      MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Person)
      path = Rails.root.join('config','data_definitions','events','*.yml')
      MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Event)
      flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: "data types"
      redirect_to admin_path
    end

    def import_classifications
      path = Rails.root.join('config','data_definitions','classifications.yml')
      MasterData::ImportClassifications.new.import(path.to_s)
      flash[:notice] = I18n.t :imported, scope: [:controllers, :job], data: "basic classification trees"
      redirect_to admin_path
    end

    def classifications
    end

    def logs
      @dataname = params[:dataname]
    end

  end
end
