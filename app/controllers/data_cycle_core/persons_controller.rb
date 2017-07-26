module DataCycleCore
  class PersonsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Personen", "", "/persons"

    #layout "data_cycle_core/creative_works_edit"

    def index
      @persons = DataCycleCore::Person.all().where(:template => false).order(updated_at: :desc).page(params[:page])
      @person = DataCycleCore::Person.new
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

      #only for testing
      @creativeWork = @person

      render layout: "data_cycle_core/creative_works_edit"

    end

    def new
      @person = DataCycleCore::Person.new
    end

    def create

      @person = create_internal(params[:template])

      set_breadcrumb_for @person

      if @person.nil?
        redirect_to :back
        return
      end

      respond_to do |format|
        #validate ?
        if !@person.nil? && @person.save
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: 'Person'
          format.html { redirect_to @person }
          format.json { render :json => @person }
        else
          redirect_to :back
          return
        end
      end

    end

    def edit
      @creativeWork = DataCycleCore::Person.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", creative_work_path(@creativeWork)
      @dataSchema = @creativeWork.get_data_hash
      render layout: "data_cycle_core/creative_works_edit"
    end

    def update
      @creativeWork = DataCycleCore::Person.find(params[:id])
      set_breadcrumb_for @creativeWork
      add_breadcrumb "", "Edit", creative_work_path(@creativeWork)
      object_params = person_params('persons', @creativeWork.metadata['validation']['name'], 'Person')

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@creativeWork.metadata['validation'], false)

      # add creator id
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
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Person'
        # redirect_to @creativeWork
        redirect_to edit_person_path(@creativeWork)
      else
        render 'edit'
      end
    end

    def validate_single_data
      @person = DataCycleCore::Person.find(params[:id])

      object_params = person_params('persons', @person.metadata['validation']['name'], 'Person')

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@person.metadata['validation'])
      valid = @person.validate(datahash)

      render :json => valid.to_json
    end

    private

      def person_params(storage_location, template_name, template_description)

        datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
        params.require(:person).permit(:datahash => datahash)

      end

      #refactor
      def create_internal(template)

        object_params = person_params('persons', template, 'Person')
        person = DataCycleCore::Person.new(object_params)

        template = DataCycleCore::Person.where(template: true, headline: template, description: "Person").first
        validation = template.metadata['validation']

        person.metadata = { 'validation' => validation }
        person.save

        if !object_params[:datahash].nil?
          datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],person.metadata['validation'])
          datahash[:creator] = current_user[:id]
        end

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

        person.set_data_hash(datahash)

        #validate ?
        if person.save
          return person
        else
          return nil
        end

      end

      def set_breadcrumb_for person
        #set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb person.metadata['validation']['name'], "#{person.givenName} #{person.familyName}", person_path(person.id)
      end

  end
end
