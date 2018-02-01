module DataCycleCore
  class StoredFiltersController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource       # from cancancan (authorize)

    def create
      @contents = get_filtered_results
      @stored_filter = save_filter

      redirect_to(root_path(stored_filter: @stored_filter), notice: (I18n.t :created, scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
    end

    def destroy
      @stored_filter.update_attributes(name: nil)

      redirect_back(fallback_location: root_path, notice: (I18n.t :destroyed, scope: [:controllers, :success], data: 'Filter', locale: DataCycleCore.ui_language))
    end

    private

    def create_params
    end

    def stored_filter_params
      params.require(:stored_filter).permit(:name)
    end
  end
end
