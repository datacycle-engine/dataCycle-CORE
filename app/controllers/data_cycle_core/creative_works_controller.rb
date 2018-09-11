# frozen_string_literal: true

module DataCycleCore
  class CreativeWorksController < ContentsController
    include DataCycleCore::Filter

    after_action :check_final, only: :update
    after_action :set_publication_attributes, only: :update, if: -> { DataCycleCore::Feature::PublicationSchedule.enabled? }

    def show
      @content = DataCycleCore::CreativeWork.find(params[:id])

      redirect_back(fallback_location: root_path) && return if @content.nil?

      if DataCycleCore::Feature::Container.enabled? && @content.content_type?('entity') && !['Bild', 'Video', 'Video-Serie', 'Foto-Serie'].include?(@content.template_name)
        I18n.with_locale(DataCycleCore.ui_language) do
          @parents = DataCycleCore::CreativeWork.where("schema ->> 'content_type' = 'container' AND template = FALSE").includes(:translations).map { |c| [c.title, c.id] }.presence&.to_h
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        if DataCycleCore::Feature::Container.enabled? && @content.content_type?('container')
          @filters = params[:f].presence&.values&.reject { |f| f['v'].blank? } || []
          @filters.push(
            {
              't' => 'part_of',
              'v' => @content.id
            }
          )

          @language ||= params.fetch(:language, [current_user.default_locale])
          if @content.children.present?
            @paginate_object = get_filtered_results
            @total = @paginate_object.count_distinct
            @paginate_object = @paginate_object.distinct_by_content_id(@order_string).content_includes.page(params[:page])
            @total_pages = (@total.to_f / 25).ceil
            @contents = @paginate_object.map(&:content_data)
          end

          @entities = DataCycleCore::CreativeWork.where("template = ? AND schema ->> 'content_type' = ?", true, 'entity').order(:template_name)
          @entities = @entities.where('template_name NOT IN(?)', DataCycleCore.excluded_filter_classifications + DataCycleCore.excluded_new_item_objects)
          @entities = DataCycleCore::Feature::Container.apply_allowed_contents(@content, @entities)
          @entities = DataCycleCore::Feature::Container.apply_excluded_contents(@content, @entities)
        end

        respond_to do |format|
          format.json { redirect_to polymorphic_path([:api, :v2, @content]) }
          format.html { render && return }
        end
      end
    end

    def create
      if params[:source] == 'object_browser'
        authorize!(:create_in_objectbrowser, data_cycle_object(controller_name))
      else
        authorize!(:create, data_cycle_object(controller_name))
      end

      locale = I18n.available_locales.include?(params[:locale].try(:to_sym)) ? params[:locale].try(:to_sym) : I18n.locale
      I18n.with_locale(locale) do
        source = Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }] if params[:source].present?
        object_params = content_params(controller_name, params[:template])

        @content = DataCycleCore::DataHashService.create_internal_object(controller_name, params[:template], object_params, current_user)

        redirect_back(fallback_location: root_path) && return if @content.nil?

        after_create(@content, current_user)

        if !@content.nil? && @content.save
          execute_after_create_webhooks @content
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
          redirect_to(edit_polymorphic_path(@content, (source || {}).merge(watch_list_id: @watch_list))) && return
        else
          redirect_back(fallback_location: root_path) && return
        end
      end
    end

    def compare
      @content = data_cycle_object(controller_name).includes(:classifications).find(params[:id])
      authorize! :show, @content

      redirect_back(fallback_location: root_path, alert: (I18n.t :no_source, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if source_params.blank?

      @diff_source = source_params[:source_type].constantize.find(source_params[:source_id])

      redirect_back(fallback_location: root_path) && return if @diff_source.nil? || @content.nil?

      I18n.with_locale(@content.first_available_locale) do
        @data_schema = @content.get_data_hash
      end

      I18n.with_locale(@diff_source.first_available_locale) do
        @diff_schema = @diff_source.diff(@data_schema)
      end
    end

    def edit
      @content = DataCycleCore::CreativeWork.includes(:classifications).find(params[:id])

      # get show data for split view
      if source_params.present?
        @split_type = source_params[:source_type].constantize
        @split_source = @split_type.find(source_params[:source_id])
        @split_schema = []

        unless @split_source.nil?
          I18n.with_locale(@split_source.first_available_locale) do
            @split_schema = @split_source.get_data_hash
          end
        end
      end

      if params[:locale] && !@content.translated_locales.include?(params[:locale]) && I18n.available_locales.include?(params[:locale]&.to_sym) && (DataCycleCore.translatable_types & [@content.class.name, @content.template_name]).present?
        I18n.with_locale(params[:locale]) do
          @content.save
        end
      end

      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        redirect_to(creative_work_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless can?(:edit, @content)

        render && return
      end
    end

    def update
      @content = DataCycleCore::CreativeWork.find(params[:id])
      I18n.with_locale(@content.first_available_locale(params[:locale])) do
        redirect_to(creative_work_path(@content), alert: (I18n.t :no_permission, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return unless can?(:update, @content)

        object_params = content_params(controller_name, @content.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(object_params[:datahash], @content.schema, false)
        #
        # known bugs:
        # saving without changed properites after initial create is identified as change. (nil => "")
        # adding embedded objects, save, reopen, save is identified as change (is_part_of changes from nil to parent_id)
        #
        # data_hash_has_changes = DataCycleCore::DataHashService.data_hash_is_dirty?(
        #   datahash.merge({ 'id' => @content.id, 'release_id' => object_params[:release_id], 'release_comment' => object_params[:release_comment] }),
        #   @content.get_data_hash.merge({ 'release_id' => @content.release_id, 'release_comment' => @content.release_comment })
        # )

        # unless data_hash_has_changes
        #   flash[:info] = I18n.t :not_modified, scope: [:controllers, :info], data: @content.template_name, locale: DataCycleCore.ui_language
        #   if (Rails.env.development? || params[:splitview]) && !params[:finalize]
        #     redirect_back(fallback_location: root_path)
        #   else
        #     redirect_to creative_work_path(@content, watch_list_id: @watch_list)
        #   end
        #   return
        # end

        valid = @content.set_data_hash(data_hash: datahash, current_user: current_user)

        # @content.release_id = object_params[:release_id]
        # @content.release_comment = object_params[:release_comment]

        redirect_to(edit_creative_work_path(@content, watch_list_id: @watch_list), alert: valid[:error]) && return if valid[:error].present?

        execute_after_update_webhooks @content
        flash[:success] = I18n.t(:updated, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language)

        if (Rails.env.development? || params[:splitview]) && !params[:finalize]
          redirect_back(fallback_location: root_path) && return
        else
          redirect_to(polymorphic_path(@content, watch_list_id: @watch_list)) && return
        end
      end
    end

    def destroy
      @content = DataCycleCore::CreativeWork.find(params[:id])
      @content.destroy_content
      @content.destroy

      execute_after_destroy_webhooks @content

      flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: 'Creative Work', locale: DataCycleCore.ui_language

      if @content.parent.nil?
        redirect_to root_path
      else
        redirect_to polymorphic_path(@content.parent, watch_list_id: @watch_list)
      end
    end

    def import
      content = params[:data].as_json
      external_source = DataCycleCore::ExternalSource.find(content['source_key'])
      api_strategy_class = DataCycleCore.allowed_api_strategies.find { |object| object == external_source.config['api_strategy'] }
      api_strategy = api_strategy_class&.constantize&.new(external_source, 'creative_work', content.values.first['url'].split('/').last)
      @content = api_strategy.create(content.except('source_key'))
      @content = @content.try(:first)

      respond_to do |format|
        format.js do
          if params[:render_html]
            flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @content.template_name, locale: DataCycleCore.ui_language
            render js: "document.location = '#{polymorphic_path(@content)}'"
          end
        end
      end
    end

    def set_parent
      @content = DataCycleCore::CreativeWork.find(params[:id])
      authorize! :edit, @content

      redirect_back(fallback_location: root_path, alert: I18n.t(:invalid_parent, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if parent_params[:parent_id].blank?

      @parent = DataCycleCore::CreativeWork.find(parent_params[:parent_id])

      I18n.with_locale(@content.first_available_locale) do
        if @content.update_column(:is_part_of, @parent.id)
          redirect_back(fallback_location: root_path, notice: I18n.t(:moved_to, scope: [:controllers, :success], locale: DataCycleCore.ui_language, data: @parent.title)) && return
        else
          redirect_back(fallback_location: root_path, alert: @content.errors.full_messages) && return
        end
      end
    end

    private

    def after_create(content, current_user)
      object_params = content_params(controller_name, params[:template])

      return if content.schema['content_type'] == 'container' || ['Video-Serie', 'Foto-Serie'].include?(params[:template])
      if params[:parent_id].blank? && params[:template] == DataCycleCore::Feature::IdeaCollection.template
        parent = DataCycleCore::DataHashService.create_internal_object('creative_works', params[:parent_template], object_params, current_user)
        life_cycle_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::IdeaCollection.life_cycle_stage, :id)
        parent.set_data_hash_attribute(DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(parent).first, [life_cycle_id], current_user)
        content.is_part_of = parent.id
      elsif params[:parent_id].present?
        content.is_part_of = params[:parent_id]
        # set_life_cycle to recherche for both
        if params[:template] == DataCycleCore::Feature::IdeaCollection.template
          life_cycle_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(DataCycleCore::Feature::IdeaCollection.life_cycle_stage, :id)
          parent = DataCycleCore::CreativeWork.find_by(id: content.is_part_of)
          parent.set_life_cycle_classification(DataCycleCore::Feature::LifeCycle.allowed_attribute_keys(parent).first, life_cycle_id, current_user)
        end
        # get inherit attributes
        source = Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }] if params[:source].present?

        split_type = data_cycle_object(source['source_type'].demodulize.tableize) if source&.dig('source_type').present?
        split_source = split_type.find(source['source_id']) if source&.dig('source_id').present? && split_type.present?
        if split_source.present?
          inherit_datahash = content.get_inherit_datahash(split_source)
        else
          inherit_datahash = content.get_inherit_datahash(content.parent)
        end

        redirect_back(fallback_location: root_path, alert: I18n.t(:invalid_parent_attr, scope: [:controllers, :error], locale: DataCycleCore.ui_language)) && return if inherit_datahash.nil?

        content.set_data_hash(data_hash: inherit_datahash, current_user: current_user, prevent_history: true)
      end
    end

    def source_params
      if params[:source]
        ActionController::Parameters.new(Hash[params[:source].split(',').collect { |x| x.strip.split('=>') }]).permit(:source_id, :source_type)
      elsif params[:source_id] && params[:source_type]
        params.permit(:source_id, :source_type)
      end
    end

    def parent_params
      params.permit(:parent_id)
    end

    def execute_after_update_webhooks(data)
      Webhook::Update.execute_all(data)
    end

    def set_publication_attributes
      return if DataCycleCore.features.dig(:publication_schedule, :classification_keys).blank? || !DataCycleCore::Feature::PublicationSchedule.available?(@content) || !@content.respond_to?('publication_schedule')
      I18n.with_locale(@content.first_available_locale) do
        datahash_params = content_params('creative_works', @content.template_name)
        datahash = DataCycleCore::DataHashService.flatten_datahash_value(datahash_params[:datahash], @content.schema, false)

        DataCycleCore.features.dig(:publication_schedule, :classification_keys).each do |tree_label|
          @content.set_data_hash_attribute(tree_label, datahash.dig('publication_schedule')&.map { |p| p[tree_label] }&.flatten&.uniq, current_user)
        end
      end
    end

    def check_final
      if params[:finalize] && (
        @content.data_links.where(receiver_id: current_user.id, permissions: 'write').present? ||
        @content.watch_lists.includes(:data_links).where(data_links: { receiver_id: current_user.id }).exists?
      )
        @content.data_links.where(receiver_id: current_user.id, permissions: 'write').update(permissions: 'read') if @content.data_links.where(receiver_id: current_user.id, permissions: 'write').present?

        if DataCycleCore::Feature::Releasable.allowed?(@content)
          I18n.with_locale(@content.first_available_locale) do
            @content.set_data_hash_attribute('release_status_id', DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).where(name: DataCycleCore::Feature::Releasable.get_stage('review'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } }).presence&.ids, current_user)
          end
        end
      end
    end
  end
end
