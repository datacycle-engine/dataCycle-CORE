module DataCycleCore
  class EventsController < ContentsController
    before_action :authenticate_user!   # from devise (authenticate)
    load_and_authorize_resource         # from cancancan (authorize)

    def index
    end

    def show
    end

    def create
    end

    def edit
    end

    def update
    end

    private

    def create_params
    end

  end
end
