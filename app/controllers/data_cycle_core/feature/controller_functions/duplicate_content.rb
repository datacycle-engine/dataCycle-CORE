# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateContent
        def create_duplication
          @object = DataCycleCore::Thing.find_by(id: params[:id])
          authorize! :create, @object
          new_content = DataCycleCore::DataHashService.create_duplicate(content: @object, current_user: current_user)
          new_content.set_data_hash(data_hash: { 'name' => "DUPLICATE: #{new_content.title}" }, current_user: current_user, partial_update: true)
          redirect_to(thing_path(new_content, watch_list_params.merge(locale: I18n.locale)), notice: (I18n.t :created_duplication, scope: [:controllers, :info], data: new_content.title, locale: DataCycleCore.ui_language))
        end
      end
    end
  end
end