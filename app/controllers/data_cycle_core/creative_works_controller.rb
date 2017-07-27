module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Themenwelten", "", "/"

    def index

    end

    def show
      @creativeWork = DataCycleCore::CreativeWork.find_by(id: params[:id])

      if @creativeWork.nil?
        redirect_to :back
        return
      end

      set_breadcrumb_for @creativeWork

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @creativeWork.get_data_hash

      if @creativeWork.metadata['validation']['content_type'] == 'variant'
        render layout: "data_cycle_core/creative_works_edit"
      else
        render layout: "data_cycle_core/creative_works_show"
      end

    end

    def create
      object_params = creative_work_params('creative_works', params[:template], 'CreativeWork')
      @creativeWork = DataCycleCore::DataHashService.create_internal_object('creative_works', params[:template], 'CreativeWork', object_params, current_user)

      if @creativeWork.nil?
        redirect_to :back
        return
      end

      if params[:template] != "Thema"
        if params['parent'].nil? || params['parent'].blank?
          #create new thema
          if params[:template] == "Recherche"
            thema = DataCycleCore::DataHashService.create_internal_object('creative_works', "Thema", 'CreativeWork', object_params, current_user)
            @creativeWork.isPartOf = thema.id unless thema.nil?
          else
            flash[:error] = I18n.t :invalid_parent, scope: [:controllers, :error]
            redirect_to :back
            return
          end
        else
          #set as parent
          @creativeWork.isPartOf = params['parent']
          #get inherit attributes
          inherit_datahash = get_inherit_datahash(@creativeWork)
          if inherit_datahash.nil?
            flash[:error] = I18n.t :invalid_parent_attr, scope: [:controllers, :error]
            redirect_to :back
            return
          end
          @creativeWork.set_data_hash(inherit_datahash)
        end
      end

      #validate ?
      if !@creativeWork.nil? && @creativeWork.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name']
        redirect_to @creativeWork
      else
        redirect_to :back
        return
      end

    end

    def edit
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      @place = DataCycleCore::Place.new
      @person = DataCycleCore::Person.new
      set_breadcrumb_for @creativeWork
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", creative_work_path(@creativeWork)
      @dataSchema = @creativeWork.get_data_hash

      render layout: "data_cycle_core/creative_works_edit"
    end

    def update
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])

      object_params = creative_work_params('creative_works', @creativeWork.metadata['validation']['name'], 'CreativeWork')
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.metadata['validation'],false)

      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_creative_work_path(@creativeWork)
        return
      end

      @creativeWork.set_data_hash(datahash)

      if @creativeWork.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name']
        
        if Rails.env.development?
          redirect_to edit_creative_work_path(@creativeWork) if Rails.env.development?
        else
          redirect_to @creativeWork
        end

      else
        render 'edit'
      end
    end

    def validate_single_data

      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      object_params = creative_work_params('creative_works', @creativeWork.metadata['validation']['name'], 'CreativeWork')
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.metadata['validation'])
      valid = @creativeWork.validate(datahash)
      render :json => valid.to_json

    end

    private

      def creative_work_params(storage_location, template_name, template_description)

        datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
        params.require(:creative_work).permit(:datahash => datahash)

      end

      def is_number? string
        true if Float(string) rescue false
      end

      def get_inherit_datahash(creativeWork)

        data_hash = creativeWork.get_data_hash
        parent = DataCycleCore::CreativeWork.find_by(id: creativeWork.isPartOf)

        if parent.nil?
          return nil
        end

        parent_data_hash = parent.get_data_hash

        #topics
        data_hash['topics'] = parent_data_hash['topics']
        #markets
        data_hash['markets'] = parent_data_hash['markets']
        #tags
        data_hash['tags'] = parent_data_hash['tags']
        #state
        data_hash['state'] = parent_data_hash['state']
        #kind
        data_hash['kind'] = parent_data_hash['kind']
        #season
        data_hash['season'] = parent_data_hash['season']

        return data_hash.compact!

      end

      def set_breadcrumb_for creativeWork
        set_breadcrumb_for creativeWork.parent if creativeWork.parent
        name = (!creativeWork.content.nil? && !creativeWork.content['headline'].nil?) ? creativeWork.content['headline'] : ''
        add_breadcrumb creativeWork.metadata['validation']['name'], name, creative_work_path(creativeWork.id)
      end

  end
end
