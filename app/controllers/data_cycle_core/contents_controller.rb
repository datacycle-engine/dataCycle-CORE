module DataCycleCore
  class ContentsController < ApplicationController
    before_action :set_watch_list

    def new_embedded_object
      respond_to(:js)
    end

    def render_embedded_object
      object_type = DataCycleCore.content_tables.find { |object| object == params[:definition]['storage_location'] }
      @object = ('DataCycleCore::' + object_type.singularize.classify).constantize.find_by(id: params[:id])
      respond_to(:js)
    end

    def gpx
      object_type = DataCycleCore.content_tables.find { |object| object == params[:type] }
      @object = ('DataCycleCore::' + object_type.singularize.classify).constantize.find_by(id: params[:id])

      send_data @object.create_gpx, filename: "#{@object.title.blank? ? 'unnamed_place' : @object.title.underscore.parameterize(separator: '_')}.gpx", type: 'gpx/xml'
    end

    def set_life_cycle
      object_type = DataCycleCore.content_tables.find { |object| object == controller_name }
      @object = ('DataCycleCore::' + object_type.singularize.classify).constantize.find_by(id: params[:id])

      # Create idea_collection if it doesn't exist and active life_cycle_stage is correct
      if @object.is_content_type?('container') && helpers.life_cycle_items.dig(DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage), :id) == life_cycle_params[:id] && !@object.children.where(template_name: DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage)).exists?
        idea_collection_params = ActionController::Parameters.new({ datahash: { headline: @object.headline } }).permit!
        idea_collection = DataCycleCore::DataHashService.create_internal_object(object_type, DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage), idea_collection_params, current_user)
        idea_collection.is_part_of = @object.id unless @object.nil?
        idea_collection.save
      end

      @object.set_classification_with_children(DataCycleCore.features.dig(:life_cycle, :attribute_key), life_cycle_params[:id], current_user)

      redirect_back(fallback_location: root_path, notice: (I18n.t :moved_to, scope: [:controllers, :success], data: life_cycle_params[:name], locale: DataCycleCore.ui_language))
    end

    def validate
      object_type = DataCycleCore.content_tables.find { |object| object == controller_name }
      @object = ('DataCycleCore::' + object_type.singularize.classify).constantize.find_by(id: params[:id])
      object_params = content_params(object_type, @object.template_name)
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @object.schema)
      valid = @object.validate(datahash)
      render json: valid.to_json
    end

    private

    def set_watch_list
      watch_list = DataCycleCore::WatchList.find(params[:watch_list_id]) if params[:watch_list_id]
      @watch_list = watch_list if can?(:manage, watch_list)
    end

    def life_cycle_params
      params.require(:life_cycle).permit(:name, :id)
    end

    def content_params(storage_location, template_name)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name)
      params.require(controller_name.singularize.to_sym).permit(datahash: datahash)
    end
  end
end
