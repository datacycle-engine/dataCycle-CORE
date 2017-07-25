module DataCycleCore
  class PersonsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Events", "", "/events"

    #layout "data_cycle_core/creative_works_edit"

    def index
      @events = DataCycleCore::Event.all().where(:template => false).order(updated_at: :desc)
      @event = DataCycleCore::Event.new
    end

    def show
      @event = DataCycleCore::Event.find_by(id: params[:id])
      set_breadcrumb_for @event

      if @event.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @event.get_data_hash

      #only for testing
      @creativeWork = @event

      render layout: "data_cycle_core/creative_works_edit"

    end

    def new
      @event = DataCycleCore::Event.new
    end

    def create

      @event = create_internal(params[:template])

      set_breadcrumb_for @event

      if @event.nil?
        redirect_to :back
        return
      end

      respond_to do |format|
        #validate ?
        if !@event.nil? && @event.save
          flash[:success] = "Successfully added new event!"
          format.html { redirect_to @event }
          format.json { render :json => @event }
        else
          redirect_to :back
          return
        end
      end

    end

    def edit
      @creativeWork = DataCycleCore::Event.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", creative_work_path(@creativeWork)
      @dataSchema = @creativeWork.get_data_hash

      render layout: "data_cycle_core/creative_works_edit"
    end

    def update
      @creativeWork = DataCycleCore::Event.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb "", "Edit", creative_work_path(@creativeWork)

      datahash = event_params[:datahash]

      # add creator id
      datahash[:creator] = current_user[:id]
      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_person_path(@creativeWork)
        return
      end

      @creativeWork.set_data_hash(datahash)

      # needed because headline != title
      update_params = {:headline => datahash[:headline]}
      @creativeWork.update_attributes(update_params)

      if @creativeWork.save
        flash[:success] = "Event updated"
        # redirect_to @creativeWork
        redirect_to edit_event_path(@creativeWork)
      else
        render 'edit'
      end
    end

    def validate_single_data
      @event = DataCycleCore::Event.find(params[:id])

      datahash = event_params[:datahash]
      valid = @person.validate(datahash)

      render :json => valid.to_json
    end

    private

      def event_params
        params.require(:event).permit(
            :id,
            :url,
            {:eventPeriod => [
                :startDate,
                :endDate
            ]},
        )
        # params.require(:creative_work).permit!
      end

      def create_internal(template)

        event = DataCycleCore::Event.new(event_params)

        template = DataCycleCore::Event.where(template: true, headline: template, description: "Event").first
        validation = template.metadata['validation']

        event.metadata = { 'validation' => validation }
        event.save

        datahash = {'url' => person_params[:url], 'startDate' => person_params[:startDate], 'endDate' => person_params[:endDate], 'creator' => current_user[:id]}

        # unless validation['properties']['data_pool'].nil?
        #   data_pool_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
        #       .where("classification_tree_labels.name = ?", validation['properties']['data_pool']['type_name'])
        #       .where("classification_aliases.name = ?", validation['properties']['data_pool']['default_value']).first
        #
        #   datahash['data_pool'] = [data_pool_classification.id] unless data_pool_classification.nil?
        # end

        #add data_type
        unless validation['properties']['data_type'].nil?
          data_type_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
              .where("classification_tree_labels.name = ?", validation['properties']['data_type']['type_name'])
              .where("classification_aliases.name = ?", validation['properties']['data_type']['default_value']).first

          datahash['data_type'] = [data_type_classification.id] unless data_type_classification.nil?
        end

        event.set_data_hash(datahash)

        #validate ?
        if event.save
          return event
        else
          return nil
        end

      end

      def set_breadcrumb_for event
        #set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb event.metadata['validation']['name'], "", event_path(event.id)
      end

  end
end
