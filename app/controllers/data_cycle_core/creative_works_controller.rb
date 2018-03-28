module DataCycleCore
  class CreativeWorksController < ContentsController
    include DataCycleCore::Filter

    before_action :authenticate_user! # from devise (authenticate)
    load_and_authorize_resource except: [:validate_single_data, :compare] # from cancancan (authorize)
    after_action :check_final, :set_publication_attributes, only: :update

    def index
    end

    def show
      @content = DataCycleCore::CreativeWork.find_by(id: params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        if @content.is_content_type?('container')
          @contents = get_filtered_results(method_name: 'part_of', parameters: @content.id) if @content.children.exists?

          @entities = DataCycleCore::CreativeWork.where("template = ? AND schema ->> 'content_type' = ?", true, 'entity').order(:template_name)
          @entities = @entities.where(template_name: @content.schema&.dig('features', 'container', 'allowed')) if @content.schema&.dig('features', 'container', 'allowed')
          @entities = @entities.where.not(template_name: @content.schema&.dig('features', 'container', 'excluded')) if @content.schema&.dig('features', 'container', 'excluded')
        end

        @release_status = DataCycleCore::Release.find_by(id: @content.release_id) if @content.schema['releasable'] && !@content.release_id.nil?
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
        source = Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }] unless params[:source].blank?
        object_params = creative_work_params('creative_works', params[:template])
        @creativeWork = DataCycleCore::DataHashService.create_internal_object('creative_works', params[:template], object_params, current_user)
        if @creativeWork.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        after_create(@creativeWork, current_user)

        if !@creativeWork.nil? && @creativeWork.save
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @creativeWork.template_name, locale: DataCycleCore.ui_language
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

      if params[:locale] && !@content.translated_locales.include?(params[:locale]) && I18n.available_locales.include?(params[:locale]&.to_sym) && (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        unless @content.read_write?
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
        object_params = creative_work_params('creative_works', @creativeWork.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.schema, false)

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
          flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @creativeWork.template_name, locale: DataCycleCore.ui_language
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
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @creativeWork.template_name, locale: DataCycleCore.ui_language

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
      object_params = creative_work_params('creative_works', @creativeWork.template_name)
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @creativeWork.schema)
      valid = @creativeWork.validate(datahash)
      render json: valid.to_json
    end

    def after_create(content, current_user)
      object_params = creative_work_params('creative_works', params[:template])
      if content.schema['content_type'] != 'container' && params[:template] != 'Video-Serie'
        if params[:parent].blank? && params[:template] == DataCycleCore.features.dig(:life_cycle, :idea_collection, :template)
          parent = DataCycleCore::DataHashService.create_internal_object('creative_works', params[:parent_template], object_params, current_user)
          life_cycle_id = helpers.life_cycle_items.dig(DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage), :id)
          parent.set_data_hash_attribute(DataCycleCore.features.dig(:life_cycle, :attribute_key), [life_cycle_id], current_user)
          content.is_part_of = parent.id
        elsif params[:parent].present?
          content.is_part_of = params[:parent]
          # set_life_cycle to recherche for both
          if params[:template] == DataCycleCore.features.dig(:life_cycle, :idea_collection, :template)
            life_cycle_id = helpers.life_cycle_items.dig(DataCycleCore.features.dig(:life_cycle, :idea_collection, :life_cycle_stage), :id)
            parent = DataCycleCore::CreativeWork.find_by(id: content.is_part_of)
            parent.set_classification_with_children(DataCycleCore.features.dig(:life_cycle, :attribute_key), life_cycle_id, current_user)
          end
          # get inherit attributes
          source = Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }] if params[:source].present?
          split_type = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify) }.find { |object| object == source['source_type'].classify } if source&.dig('source_type').present?
          split_source = split_type.constantize.find(source['source_id']) if source&.dig('source_id').present? && split_type.present?
          if split_source.present?
            inherit_datahash = content.get_inherit_datahash(split_source)
          else
            inherit_datahash = content.get_inherit_datahash(content.parent)
          end

          redirect_back(fallback_location: root_path, alert: I18n.t(:invalid_parent_attr, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if inherit_datahash.nil?

          content.set_data_hash(data_hash: inherit_datahash, current_user: current_user, prevent_history: true)
        end
      end
    end

    private

    def create_params
    end

    def creative_work_params(storage_location, template_name)
      datahash = DataCycleCore::DataHashService.get_object_params(storage_location, template_name)
      params.require(:creative_work).permit(:release_id, :release_comment, datahash: datahash)
    end

    def source_params
      if params[:source]
        ActionController::Parameters.new(Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }]).permit(:source_id, :source_type)
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

    def set_publication_attributes
      if DataCycleCore.features.dig(:publication_schedule, :classification_keys).present? && @creativeWork.respond_to?('publication_schedule')
        I18n.with_locale(@creativeWork.first_available_locale) do
          datahash_params = creative_work_params('creative_works', @creativeWork.template_name)
          datahash = DataCycleCore::DataHashService.flatten_datahash_value(datahash_params[:datahash], @creativeWork.schema, false)

          DataCycleCore.features.dig(:publication_schedule, :classification_keys).each do |tree_label|
            @creativeWork.set_data_hash_attribute(tree_label, datahash.dig('publication_schedule')&.map { |p| p[tree_label] }&.flatten&.uniq, current_user)
          end
        end
      end
    end

    def check_final
      if params[:finalize] && @creativeWork.data_links.where(receiver_id: current_user.id, permissions: 'write').size.positive?
        @creativeWork.data_links.where(receiver_id: current_user.id, permissions: 'write').first.update_attribute(:permissions, 'read')

        I18n.with_locale(@creativeWork.first_available_locale) do
          @creativeWork.update_attribute(:release_id, DataCycleCore::Release.where(release_code: DataCycleCore.release_codes[:review]).try(:first).try(:id)) unless DataCycleCore.release_codes.blank?
        end
      end
    end
  end
end
