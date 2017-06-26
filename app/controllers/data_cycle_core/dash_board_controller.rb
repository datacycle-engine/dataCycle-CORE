module DataCycleCore
  class DashBoardController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Themenwelten", "", "/"

    def home
      @statOutdoorActive = StatsDatabase.new(current_user.id)
      @statJobQueue = StatsJobQueue.new.update
      add_breadcrumb "Admin", "Home", "/admin"
    end

    def download
      @uuid = params[:uuid]
      DownloadJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.name
      flash[:notice] = "added #{name}/#{@uuid} to job-queue"
      redirect_to admin_path
    end

    def import
      @uuid = params[:uuid]
      ImportJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.name
      flash[:notice] = "added #{name}/#{@uuid} to job-queue"
      redirect_to admin_path
    end

    def import_templates
      path = Rails.root.join('config','data_definitions','creative_works.yml')
      MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::CreativeWork)
      flash[:notice] = "imported data types YAML file"
      redirect_to admin_path
    end

    def import_classifications
      path = Rails.root.join('config','data_definitions','classifications.yml')
      MasterData::ImportClassifications.new.import(path.to_s)
      flash[:notice] = "imported basic classification trees from YAML file"
      redirect_to admin_path
    end

    def logs
      @dataname = params[:dataname]
    end

  end
end
