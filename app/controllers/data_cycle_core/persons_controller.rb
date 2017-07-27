module DataCycleCore
  class PersonsController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Personen", "", "/persons"

    def index
      @persons = DataCycleCore::Person.all().where(:template => false).order(updated_at: :desc).page(params[:page])
      @person = DataCycleCore::Person.new
    end

    def show
      @person = DataCycleCore::Person.find_by(id: params[:id])

      if @person.nil?
        redirect_to :back
      end

      set_breadcrumb_for @person

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @person.get_data_hash

      render layout: "data_cycle_core/creative_works_edit"

    end

    def create
      object_params = person_params('persons', params[:template], 'Person')
      @person = DataCycleCore::DataHashService.create_internal_object('persons', params[:template], 'Person', object_params, current_user)

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
      @person = DataCycleCore::Person.find(params[:id])
      set_breadcrumb_for @person
      add_breadcrumb '<i aria-hidden="true" class="fa fa-pencil"></i> Bearbeiten'.html_safe, "", creative_work_path(@person)
      @dataSchema = @person.get_data_hash
      render layout: "data_cycle_core/creative_works_edit"
    end

    def update
      @person = DataCycleCore::Person.find(params[:id])

      object_params = person_params('persons', @person.metadata['validation']['name'], 'Person')
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash],@person.metadata['validation'], false)

      # add creator id
      valid = @person.validate(datahash)

      if valid.key?(:error) && !valid[:error].empty?
        flash[:error] = valid[:error]
        redirect_to edit_person_path(@person)
        return
      end

      @person.set_data_hash(datahash)

      if @person.save
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: 'Person'

        if Rails.env.development?
          redirect_to edit_person_path(@person) if Rails.env.development?
        else
          redirect_to @person
        end

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

      def set_breadcrumb_for person
        #set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb person.metadata['validation']['name'], "#{person.givenName} #{person.familyName}", person_path(person.id)
      end

  end
end
