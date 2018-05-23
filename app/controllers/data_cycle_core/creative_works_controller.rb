module DataCycleCore
  class CreativeWorksController < ContentsController
    include DataCycleCore::Filter

    after_action :check_final, :set_publication_attributes, only: :update

    def show
      @content = DataCycleCore::CreativeWork.find_by(id: params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        if DataCycleCore::Feature::Container.enabled? && @content.content_type?('container')
          @contents = get_filtered_results(method_name: 'part_of', parameters: @content.id) if @content.children.exists?

          @entities = DataCycleCore::CreativeWork.where("template = ? AND schema ->> 'content_type' = ?", true, 'entity').order(:template_name)
          @entities = @entities.where('template_name NOT IN(?)', DataCycleCore.excluded_filter_classifications + DataCycleCore.excluded_new_item_objects)
          @entities = DataCycleCore::Feature::Container.apply_allowed_contents(@content, @entities)
          @entities = DataCycleCore::Feature::Container.apply_excluded_contents(@content, @entities)
        end

        @release_status = DataCycleCore::Release.find_by(id: @content.release_id) if DataCycleCore::Feature::Releasable.allowed?(@content) && !@content.release_id.nil?

        respond_to do |format|
          format.json { redirect_to api_v1_content_path(type: controller_name, id: params[:id]) }
          format.html { render 'show' }
        end
      end
    end

    def create
      locale = I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params[:locale].try(:to_sym) : I18n.locale
      I18n.with_locale(locale) do
        source = Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }] unless params[:source].blank?
        object_params = content_params(controller_name, params[:template])

        @content = DataCycleCore::DataHashService.create_internal_object(controller_name, params[:template], object_params, current_user)
        if @content.nil?
          redirect_back(fallback_location: root_path)
          return
        end

        after_create(@content, current_user)

        if !@content.nil? && @content.save
          execute_after_create_webhooks @content
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
          redirect_to edit_polymorphic_path(@content, (source || {}).merge(watch_list_id: @watch_list))
        else
          redirect_back(fallback_location: root_path)
          return
        end
      end
    end

    def compare
      @content = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])
      authorize! :show, @content

      redirect_back(fallback_location: root_path, alert: (I18n.t :no_source, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if source_params.blank?

      @source = source_params[:source_type].constantize.find(source_params[:source_id]) unless source_params.blank?

      I18n.with_locale(@content.first_available_locale) do
        @dataSchema = @content.get_data_hash.merge(@content.releasable_hash)
      end

      I18n.with_locale(@source.first_available_locale) do
        @sourceSchema = @source.get_data_hash.merge(@source.releasable_hash)
      end

      @diffSchema = helpers.get_diff(@sourceSchema, @dataSchema)
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
        unless can?(:edit, @content)
          redirect_to creative_work_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)
          return
        end

        render 'edit'
      end
    end

    def update
      @content = DataCycleCore::CreativeWork.find(params[:id])
      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        object_params = content_params(controller_name, @content.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @content.schema, false)
        #
        # known bugs:
        # saving without changed properites after initial create is identified as change. (nil => "")
        # adding embedded objects, save, reopen, save is identified as change (is_part_of changes from nil to parent_id)
        #
        data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
          datahash.merge({ 'id' => @content.id, 'release_id' => object_params[:release_id], 'release_comment' => object_params[:release_comment] }),
          @content.get_data_hash.merge({ 'release_id' => @content.release_id, 'release_comment' => @content.release_comment })
        )

        unless data_hash_has_changes
          flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @content.template_name, locale: DataCycleCore.ui_language
          if (Rails.env.development? || params[:splitview]) && !params[:finalize]
            redirect_back(fallback_location: root_path)
          else
            redirect_to creative_work_path(@content, watch_list_id: @watch_list)
          end
          return
        end

        valid = @content.set_data_hash(data_hash: datahash, current_user: current_user)

        @content.release_id = object_params[:release_id]
        @content.release_comment = object_params[:release_comment]

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_creative_work_path(@content)
          return
        end

        if @content.save
          execute_after_update_webhooks @content
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language

          if (Rails.env.development? || params[:splitview]) && !params[:finalize]
            redirect_back(fallback_location: root_path)
          else
            redirect_to polymorphic_path(@content, watch_list_id: @watch_list)
          end

        else
          render 'edit'
        end
      end
    end

    def destroy
      @content = DataCycleCore::CreativeWork.find(params[:id])
      @content .destroy_content
      @content .destroy

      execute_after_destroy_webhooks @content

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Creative Work', locale: DataCycleCore.ui_language

      if @content.parent.nil?
        redirect_to root_path
      else
        redirect_to polymorphic_path(@content .parent, watch_list_id: @watch_list)
      end
    end

    private

    def after_create(content, current_user)
      object_params = content_params(controller_name, params[:template])
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

    def source_params
      if params[:source]
        ActionController::Parameters.new(Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }]).permit(:source_id, :source_type)
      elsif params[:source_id] && params[:source_type]
        params.permit(:source_id, :source_type)
      end
    end

    def execute_after_update_webhooks(data)
      Webhook::Update.execute_all(data)
    end

    def set_publication_attributes
      if DataCycleCore.features.dig(:publication_schedule, :classification_keys).present? && DataCycleCore::Feature::PublicationSchedule.available?(@content) && @content.respond_to?('publication_schedule')
        I18n.with_locale(@content.first_available_locale) do
          datahash_params = content_params('creative_works', @content.template_name)
          datahash = DataCycleCore::DataHashService.flatten_datahash_value(datahash_params[:datahash], @content.schema, false)

          DataCycleCore.features.dig(:publication_schedule, :classification_keys).each do |tree_label|
            @content.set_data_hash_attribute(tree_label, datahash.dig('publication_schedule')&.map { |p| p[tree_label] }&.flatten&.uniq, current_user)
          end
        end
      end
    end

    def check_final
      if params[:finalize] && @content.data_links.where(receiver_id: current_user.id, permissions: 'write').size.positive?
        @content.data_links.where(receiver_id: current_user.id, permissions: 'write').first.update_attribute(:permissions, 'read')

        I18n.with_locale(@content.first_available_locale) do
          @content.update_attribute(:release_id, DataCycleCore::Release.where(release_code: DataCycleCore.release_codes[:review]).try(:first).try(:id)) unless DataCycleCore.release_codes.blank?
        end
      end
    end
  end
end
