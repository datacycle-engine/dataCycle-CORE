module DataCycleCore
  class CreativeWorksController < ContentsController

    before_action :authenticate_user!                                # from devise (authenticate)
    load_and_authorize_resource except: [:validate_single_data]      # from cancancan (authorize)

    def index
    end

    def show
      @creativeWork = DataCycleCore::CreativeWork.find_by(id: params[:id])
      I18n.with_locale(@creativeWork.first_available_locale) do

        if @creativeWork.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        if params[:mode].nil?
          @mode = "flex"
        else
          @mode = params[:mode].to_s
        end

        @release_status = DataCycleCore::Release.find_by(id: @creativeWork.release_id) if @creativeWork.metadata['validation']['releasable'] && !@creativeWork.release_id.nil?
        @dataSchema = @creativeWork.get_data_hash

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'creative_works', id: params[:id]) }
          format.html {
            if @creativeWork.metadata['validation']['content_type'] == 'variant'
              render layout: "data_cycle_core/creative_works_edit"
            else
              render layout: "data_cycle_core/creative_works_show"
            end
          }
        end
      end
    end

    def create
      locale = I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params[:locale].try(:to_sym) : I18n.locale
      I18n.with_locale(locale) do
        source = Hash[params[:source].split(",").collect{|x| x.strip.split("=>")}] unless params[:source].blank?
        object_params = creative_work_params('creative_works', params[:template], 'CreativeWork')
        @creativeWork = DataCycleCore::DataHashService.create_internal_object('creative_works', params[:template], 'CreativeWork', object_params, current_user)
        if @creativeWork.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        after_create(@creativeWork, current_user)

        if !@creativeWork.nil? && @creativeWork.save
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name'], locale: DataCycleCore.ui_language
          redirect_to edit_creative_work_path(@creativeWork, source)
        else
          redirect_back(fallback_location: root_path)
          return
        end
      end

    end

    def history
      @creativeWork = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])

      # get show data for split view
      @historySource = @creativeWork.histories.find(params[:history_id]) if !params[:history_id].nil?

      I18n.with_locale(@historySource.first_available_locale) do
        @historySchema = @historySource.get_data_hash
      end unless @historySource.nil?

      I18n.with_locale(@creativeWork.first_available_locale) do

        unless @creativeWork.read_write?
          raise "read_only"
          redirect_to creative_work_path(@creativeWork), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)
          return
        end

        @place = DataCycleCore::Place.new
        @person = DataCycleCore::Person.new
        @dataSchema = @creativeWork.get_data_hash
        @diffSchema = helpers.get_diff(@historySchema.merge(@historySource.get_releasable_hash), @dataSchema.merge(@creativeWork.get_releasable_hash))

        render layout: "data_cycle_core/creative_works_edit"
      end

    end

    def history_detail
      return history
    end

    def edit
      @creativeWork = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])

      # get show data for split view
      @splitType = params[:source_type].constantize unless params[:source_type].nil?
      @splitSource = @splitType.find(params[:source_id]) if !params[:source_id].nil? && !@splitType.nil?
      @splitSchema = []

      I18n.with_locale(@splitSource.first_available_locale) do
        @splitSchema = @splitSource.get_data_hash
      end unless @splitSource.nil?

      I18n.with_locale(@creativeWork.first_available_locale) do

        unless @creativeWork.read_write?
          raise "read_only"
          redirect_to creative_work_path(@creativeWork), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)
          return
        end

        @place = DataCycleCore::Place.new
        @person = DataCycleCore::Person.new
        @dataSchema = @creativeWork.get_data_hash
        render layout: "data_cycle_core/creative_works_edit"
      end
    end

    def update
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      I18n.with_locale(@creativeWork.first_available_locale) do

        object_params = creative_work_params('creative_works', @creativeWork.metadata['validation']['name'], 'CreativeWork')
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.metadata['validation'],false)

        #
        #known bugs:
        #saving without changed properites after initial create is identified as change. (nil => "")
        #adding embedded objects, save, reopen, save is identified as change (is_part_of changes from nil to parent_id)
        #
        data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
            datahash.merge({'id' => @creativeWork.id, 'release_id' => object_params[:release_id], 'release_comment' => object_params[:release_comment]}),
            @creativeWork.get_data_hash.merge({'release_id' => @creativeWork.release_id, 'release_comment' => @creativeWork.release_comment})
        )

        unless data_hash_has_changes
          flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @creativeWork.metadata['validation']['name'], locale: DataCycleCore.ui_language
          redirect_back(fallback_location: root_path)
          return
        end

        valid = @creativeWork.set_data_hash(data_hash: datahash, current_user: current_user)

        @creativeWork.release_id = object_params[:release_id]
        @creativeWork.release_comment = object_params[:release_comment]

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_creative_work_path(@creativeWork)
          return
        end

        if @creativeWork.save
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name'], locale: DataCycleCore.ui_language

          #after update webhooks
          execute_after_update_webhooks @creativeWork

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          elsif params[:splitview]
            redirect_back(fallback_location: root_path)
          else
            redirect_to creative_work_path(@creativeWork, trail: session[:trail])
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      @creativeWork.destroy_content
      @creativeWork.destroy

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Creative Work', locale: DataCycleCore.ui_language

      if @creativeWork.parent.nil?
        redirect_to root_path
      else
        redirect_to creative_work_path(@creativeWork.parent, trail: session[:trail])
      end

    end

    def validate_single_data

      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      object_params = creative_work_params('creative_works', @creativeWork.metadata['validation']['name'], 'CreativeWork')
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.metadata['validation'])
      valid = @creativeWork.validate(datahash)
      render :json => valid.to_json

    end


    def after_create(content, user)
      # to be implemented by specific projects
    end

    def import
      @content = DataCycleCore::DataHashService.import_data(data_set: params[:data])
      if !@content.blank? && @content.metadata.dig('validation', 'description') == params[:type].camelize
        render json: @content.to_json
      else
        render json: { errors: "no data" }
      end

    end

    private
    def create_params
    end

    def creative_work_params(storage_location, template_name, template_description)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
      params.require(:creative_work).permit(:release_id, :release_comment, :datahash => datahash)
    end

    def is_number? string
      true if Float(string) rescue false
    end

    def execute_after_update_webhooks data
      Webhook::Update.execute_all(data)
    end
  end
end
