module DataCycleCore
  class PersonsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Themenwelten", "", "/"

    #layout "data_cycle_core/creative_works_edit"

    def index

    end

    def show
      @person = DataCycleCore::Person.find_by(id: params[:id])
      set_breadcrumb_for @person

      if @person.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @person.get_data_hash
      render layout: "data_cycle_core/creative_works_edit"

    end

    def new

    end

    def create

      @person = create_internal(params[:template])

      set_breadcrumb_for @person

      if @person.nil?
        redirect_to :back
        return
      end

      #validate ?
      if !@person.nil? && @person.save
        flash[:success] = "Successfully added new person!"
        redirect_to @person
      else
        redirect_to :back
        return
      end

    end

    def edit
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", creative_work_path(@creativeWork)
      @dataSchema = @creativeWork.get_data_hash

      render layout: "data_cycle_core/creative_works_edit"
    end

    def update
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb "", "Edit", creative_work_path(@creativeWork)
      datahash = creative_work_params[:datahash]

      # add creator id
      datahash[:creator] = current_user[:id]
      valid = @creativeWork.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_creative_work_path(@creativeWork)
        return
      end

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
      @person = DataCycleCore::Person.find(params[:id])

      datahash = person_params[:datahash]
      valid = @person.validate(datahash)

      render :json => valid.to_json
    end

    private

      def person_params
        params.require(:person).permit(:datahash => [:givenName, :familyName])
        # params.require(:creative_work).permit!
      end

      def create_internal(template)

        person = DataCycleCore::Person.new(person_params)

        template = DataCycleCore::Person.where(template: true, headline: template, description: "Person").first
        validation = template.metadata['validation']

        person.metadata = { 'validation' => validation }
        person.save

        datahash = {'headline' => "#{creative_work_params[:givenName]} #{creative_work_params[:familyName]}", 'creator' => current_user[:id]}

        # unless validation['properties']['data_pool'].nil?
        #   data_pool_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
        #       .where("classification_tree_labels.name = ?", validation['properties']['data_pool']['type_name'])
        #       .where("classification_aliases.name = ?", validation['properties']['data_pool']['default_value']).first
        #
        #   datahash['data_pool'] = [data_pool_classification.id] unless data_pool_classification.nil?
        # end
        #
        # #add data_type
        # unless validation['properties']['data_type'].nil?
        #   data_type_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
        #       .where("classification_tree_labels.name = ?", validation['properties']['data_type']['type_name'])
        #       .where("classification_aliases.name = ?", validation['properties']['data_type']['default_value']).first
        #
        #   datahash['data_type'] = [data_type_classification.id] unless data_type_classification.nil?
        # end

        person.set_data_hash(datahash)

        #validate ?
        if person.save
          return person
        else
          return nil
        end

      end

      def set_breadcrumb_for creativeWork
        set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb creativeWork.metadata['validation']['name'], creativeWork.content['headline'], creative_work_path(creativeWork.id)
      end

  end
end
