module DataCycleCore
  class CreativeWorksController < ContentsController
    before_action :authenticate_user!                                # from devise (authenticate)
    load_and_authorize_resource except: [:validate_single_data]      # from cancancan (authorize)

    def index

    end

    def show
      session[:trail] = params[:trail] unless params[:trail].nil?
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
              @sources = get_sources
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
          flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name']
          redirect_to edit_creative_work_path(@creativeWork, source)
        else
          redirect_back(fallback_location: root_path)
          return
        end
      end

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
          redirect_to creative_work_path(@creativeWork), alert: (I18n.t :no_permission, scope: [:controllers, :error])
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

        valid = @creativeWork.set_data_hash(datahash, current_user)

        if valid.key?(:error) && !valid[:error].empty?
          flash[:error] = valid[:error]
          redirect_to edit_creative_work_path(@creativeWork)
          return
        end

        if @creativeWork.save
          flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name']

          if Rails.env.development?
            redirect_back(fallback_location: root_path)
          else
            redirect_to creative_work_path(@creativeWork, trail: session[:trail])
          end

        else
          render 'edit'
        end
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
        params.require(:creative_work).permit(:datahash => datahash)
      end

      def is_number? string
        true if Float(string) rescue false
      end

      def get_inherit_datahash(creativeWork)

        data_hash = creativeWork.get_data_hash
        parent = DataCycleCore::CreativeWork.find_by(id: creativeWork.is_part_of)

        if parent.nil?
          return nil
        end

        I18n.with_locale(parent.first_available_locale) do
          parent_data_hash = parent.get_data_hash

          #topics
          data_hash['topics'] = parent_data_hash['topics']
          #markets
          data_hash['markets'] = parent_data_hash['markets']
          #tags
          data_hash['tags'] = parent_data_hash['tags']
          #state
          data_hash['state'] = parent_data_hash['state']
          #kind
          data_hash['kind'] = parent_data_hash['kind']
          #season
          data_hash['season'] = parent_data_hash['season']
          #content_pool
          data_hash['data_pool'] = parent_data_hash['data_pool']
        end

        return data_hash.compact!

      end

      def get_sources
        tree_labels = helpers.get_allowed_content_types.keys
        tree_labels.push('Recherche')

        types = DataCycleCore::ClassificationAlias.where("name IN (?) AND internal = true", tree_labels).pluck(:id)

        @language = params[:language]
        @language ||= "de"

        query = DataCycleCore::Filter::CreativeWorkQueryBuilder.new(@language)
        query = query.with_classification_alias_ids(types)

        query = query.map{|c| { value: "source_id=>#{c.id}, source_type=>#{c.class.name}", label: (c.title || '') + " (" + c.content_type + ")" } }.compact

        return query
      end

  end
end
