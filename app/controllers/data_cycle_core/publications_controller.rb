module DataCycleCore
  class PublicationsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
      @contents = DataCycleCore::CreativeWork.where(template: false, template_name: 'Publikations-Status').order("(metadata ->> 'publish_at')::timestamptz ASC")
      # @total = @contents.size
    end
  end
end
