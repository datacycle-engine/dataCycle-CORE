module DataCycleCore
  class Api::V1::WatchListsController < Api::V1::ApiBaseController
    def index
      if current_user
        @watch_lists = DataCycleCore::WatchList.accessible_by(current_ability)
          .where(user: User.find_by(email: permitted_params[:user_email]) || current_user)
          .all
      else
        @watch_lists = DataCycleCore::WatchList.where(user: User.find_by!(email: permitted_params[:user_email])).all
      end

      # FIXME: Jbuilder Bug: tries to render jbuilder partial
      render plain: {
        collections: @watch_lists.map do |l|
          {
            id: l.id,
            name: l.headline,
            url: api_v1_collection_url(l),
            item_count: l.watch_list_data_hashes.count
          }
        end
      }.to_json, content_type: 'application/json'
    end

    # method to show a particular WatchList
    def show
      @watch_list = DataCycleCore::WatchList.find(permitted_params[:id])
    end


    private

    def permitted_parameter_keys
      super + [:user_email, :id]
    end
  end
end
