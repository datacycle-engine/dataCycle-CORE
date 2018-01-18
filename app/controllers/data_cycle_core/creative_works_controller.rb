module DataCycleCore
  class CreativeWorksController < ContentsController
    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: [:validate_single_data, :compare] # from cancancan (authorize)
    after_action :check_final, only: :update

    def index
    end

    def show
      @content = DataCycleCore::CreativeWork.find_by(id: params[:id])
      I18n.with_locale(@content.first_available_locale) do
        if @content.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        if params[:mode].nil?
          @mode = "flex"
        else
          @mode = params[:mode].to_s
        end

        @release_status = DataCycleCore::Release.find_by(id: @content.release_id) if @content.metadata['validation']['releasable'] && !@content.release_id.nil?
        @dataSchema = @content.get_data_hash

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: 'creative_works', id: params[:id]) }
          format.html { render 'show' }
        end
      end
    end

    def create
      locale = I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params[:locale].try(:to_sym) : I18n.locale
      I18n.with_locale(locale) do
        source = Hash[params[:source].split(",").collect { |x| x.strip.split("=>") }] unless params[:source].blank?
        object_params = creative_work_params('creative_works', params[:template], 'CreativeWork')
        @creativeWork = DataCycleCore::DataHashService.create_internal_object('creative_works', params[:template], 'CreativeWork', object_params, current_user)
        if @creativeWork.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        after_create(@creativeWork, current_user)

        if !@creativeWork.nil? && @creativeWork.save
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name'], locale: DataCycleCore.ui_language
          redirect_to edit_creative_work_path(@creativeWork, (source || {}).merge(watch_list_id: @watch_list))
        else
          redirect_back(fallback_location: root_path)
          return
        end
      end
    end

    def compare
      @creativeWork = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])
      authorize! :show, @creativeWork

      redirect_back(fallback_location: root_path, alert: (I18n.t :no_source, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if source_params.blank?

      @source = source_params[:source_type].constantize.find(source_params[:source_id]) unless source_params.blank?

      I18n.with_locale(@creativeWork.first_available_locale) do
        @dataSchema = @creativeWork.get_data_hash.merge(@creativeWork.get_releasable_hash)
      end

      I18n.with_locale(@source.first_available_locale) do
        @sourceSchema = @source.get_data_hash.merge(@source.get_releasable_hash)
      end

      @diffSchema = helpers.get_diff(@sourceSchema, @dataSchema)
    end

    def history
      @creativeWork = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])

      # get show data for split view
      @historySource = @creativeWork.histories.find(params[:history_id]) unless params[:history_id].nil?

      unless @historySource.nil?
        I18n.with_locale(@historySource.first_available_locale) do
          @historySchema = @historySource.get_data_hash
        end
      end

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
      end
    end

    def history_detail
      history
    end

    def edit
      @content = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])

      # get show data for split view
      unless source_params.blank?
        @splitType = source_params[:source_type].constantize
        @splitSource = @splitType.find(source_params[:source_id])
        @splitSchema = []

        unless @splitSource.nil?
          I18n.with_locale(@splitSource.first_available_locale) do
            @splitSchema = @splitSource.get_data_hash
          end
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        unless @content.read_write?
          raise "read_only"
          redirect_to creative_work_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)
          return
        end

        @place = DataCycleCore::Place.new
        @person = DataCycleCore::Person.new
        @dataSchema = @content.get_data_hash
        render 'edit'
      end
    end

    def update
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      I18n.with_locale(@creativeWork.first_available_locale(params[:locale])) do
        object_params = creative_work_params('creative_works', @creativeWork.metadata['validation']['name'], @creativeWork.metadata['validation']['description'])
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.metadata['validation'], false)

        #
        # known bugs:
        # saving without changed properites after initial create is identified as change. (nil => "")
        # adding embedded objects, save, reopen, save is identified as change (is_part_of changes from nil to parent_id)
        #
        data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
          datahash.merge({ 'id' => @creativeWork.id, 'release_id' => object_params[:release_id], 'release_comment' => object_params[:release_comment] }),
          @creativeWork.get_data_hash.merge({ 'release_id' => @creativeWork.release_id, 'release_comment' => @creativeWork.release_comment })
        )

        unless data_hash_has_changes
          flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @creativeWork.metadata['validation']['name'], locale: DataCycleCore.ui_language
          if (Rails.env.development? || params[:splitview]) && !params[:finalize]
            redirect_back(fallback_location: root_path)
          else
            redirect_to creative_work_path(@creativeWork, watch_list_id: @watch_list)
          end
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

          # after update webhooks
          execute_after_update_webhooks @creativeWork
          if (Rails.env.development? || params[:splitview]) && !params[:finalize]
            redirect_back(fallback_location: root_path)
          else
            redirect_to creative_work_path(@creativeWork, watch_list_id: @watch_list)
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
        redirect_to creative_work_path(@creativeWork.parent, watch_list_id: @watch_list)
      end
    end

    def validate_single_data
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      object_params = creative_work_params('creative_works', @creativeWork.metadata['validation']['name'], @creativeWork.metadata['validation']['description'])
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.metadata['validation'])
      valid = @creativeWork.validate(datahash)
      render json: valid.to_json
    end

    def after_create(content, user)
      # to be implemented by specific projects
    end

    private

    def create_params
    end

    def creative_work_params(storage_location, template_name, template_description)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name, template_description)
      params.require(:creative_work).permit(:release_id, :release_comment, datahash: datahash)
    end

    def source_params
      if params[:source]
        ActionController::Parameters.new(Hash[params[:source].split(",").collect { |x| x.strip.split("=>") }]).permit(:source_id, :source_type)
      elsif params[:source_id] && params[:source_type]
        params.permit(:source_id, :source_type)
      end
    end

    def is_number?(string)
      true if Float(string)
    rescue StandardError
      false
    end

    def execute_after_update_webhooks(data)
      Webhook::Update.execute_all(data)
    end

    def check_final
      if params[:finalize] && @creativeWork.data_links.where(receiver_id: current_user.id, permissions: 'write').size.positive?
        @creativeWork.data_links.where(receiver_id: current_user.id, permissions: 'write').first.update_attribute(:permissions, 'read')

        @creativeWork.update_attribute(:release_id, DataCycleCore::Release.where(release_code: DataCycleCore.release_codes[:review]).try(:first).try(:id)) unless DataCycleCore.release_codes.blank?
      end
    end

    # def execute_after_delete_webhooks data
    #   Webhook::Delete.execute_all(data)
    # end

    # def execute_after_create_webhooks data
    #   Webhook::Create.execute_all(data)
    # end
  end
end
