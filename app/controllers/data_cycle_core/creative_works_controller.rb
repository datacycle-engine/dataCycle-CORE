module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    def index

    end

    def show
      @creativeWork = DataCycleCore::CreativeWork.find_by(id: params[:id])
      if @creativeWork.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      render layout: "data_cycle_core/creative_works_show"
    end

    def new
      #only for testing
      @creativeWork = DataCycleCore::CreativeWork.new
      render layout: "data_cycle_core/creative_works_show"
    end

    def create

      @creativeWork = create_internal(params[:template])

      if @creativeWork.nil?
        render 'new'
        return
      end

      if params[:template] != "Thema"
        if params['parent'].nil? || params['parent'].blank?
          #create new thema
          thema = create_internal("Thema")
          @creativeWork.isPartOf = thema.id unless thema.nil?
        else
          #set as parent
          @creativeWork.isPartOf = params['parent']
        end
      end

      #validate ?
      if @creativeWork.nil? || @creativeWork.save
        flash[:success] = "Successfully added new creativeWork!"
        redirect_to @creativeWork
      else
        render 'new'
      end

    end

    def edit
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      @data = @creativeWork.get_data_type
      @dataSchema = @creativeWork.get_data_hash

      render layout: "data_cycle_core/creative_works_show"
    end

    def update
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      datahash = creative_work_params[:datahash]

      # add creator id
      datahash[:creator] = current_user[:id]
      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_creative_work_path(@creativeWork)
        return
      end

      puts "data -------> #{datahash.awesome_inspect}"

      @creativeWork.set_data_hash(datahash)

      # needed because headline != title
      update_params = {:headline => datahash[:headline]}
      @creativeWork.update_attributes(update_params)

      if @creativeWork.save
        flash[:success] = "CreativeWork updated"
        # redirect_to @creativeWork
        redirect_to edit_creative_work_path(@creativeWork)
      else
        render 'edit'
      end
    end

    def validate_single_data
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])

      datahash = creative_work_params[:datahash]
      valid = @creativeWork.validate(datahash)

      render :json => valid.to_json
    end

    #dev views for michi
    def demotopic

    end

    def demoarticle

    end

    private

      def creative_work_params
        params.require(:creative_work).permit(:headline, :datahash => [:headline,:text,:description,:state => [],:topics => [],:markets => [],:tags => [], :validityPeriod => [:validFrom, :validUntil], :image => [], :video => []])
        # params.require(:creative_work).permit!
      end

      def create_internal(template)

        creative_work = DataCycleCore::CreativeWork.new(creative_work_params)

        template = DataCycleCore::CreativeWork.where(template: true, headline: template, description: "CreativeWork").first
        validation = template.metadata['validation']

        creative_work.metadata = { 'validation' => validation }
        creative_work.save

        datahash = {'headline' => creative_work_params[:headline], 'creator' => current_user[:id]}

        unless validation['properties']['data_pool'].nil?
          data_pool_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
              .where("classification_tree_labels.name = ?", validation['properties']['data_pool']['type_name'])
              .where("classification_aliases.name = ?", validation['properties']['data_pool']['default_value']).first

          datahash['data_pool'] = [data_pool_classification.id] unless data_pool_classification.nil?
        end

        #add data_type
        unless validation['properties']['data_type'].nil?
          data_type_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
              .where("classification_tree_labels.name = ?", validation['properties']['data_type']['type_name'])
              .where("classification_aliases.name = ?", validation['properties']['data_type']['default_value']).first

          datahash['data_type'] = [data_type_classification.id] unless data_type_classification.nil?
        end

        creative_work.set_data_hash(datahash)

        #validate ?
        if creative_work.save
          return creative_work
        else
          return nil
        end

      end

  end
end
