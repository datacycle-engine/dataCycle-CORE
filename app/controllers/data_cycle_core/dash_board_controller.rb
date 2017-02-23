module DataCycleCore
  class DashBoardController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def home
      byebug
      @statOutdoorActive = StatsDatabase.new(current_user.id)
      @statJobQueue = StatsJobQueue.new.update
    end

    def download
      @uuid = params[:uuid]
      DownloadJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.external_name
      flash[:notice] = "added #{name}/#{@uuid} to job-queue"
      redirect_to root_path
    end

    def import
      @uuid = params[:uuid]
      ImportJob.perform_later(@uuid)
      name = ExternalSource.where(id: @uuid).first.external_name
      flash[:notice] = "added #{name}/#{@uuid} to job-queue"
      redirect_to root_path
    end

    def logs
      @dataname = params[:dataname]
    end

  end
end
