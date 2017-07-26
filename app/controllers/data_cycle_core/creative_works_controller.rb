module DataCycleCore
  class CreativeWorksController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)
    add_breadcrumb "Themenwelten", "", "/"

    def index
    end

    def show
      @creativeWork = DataCycleCore::CreativeWork.find_by(id: params[:id])
      set_breadcrumb_for @creativeWork
      if @creativeWork.nil?
        redirect_to root
      end

      if params[:mode].nil?
        @mode = "flex"
      else
        @mode = params[:mode].to_s
      end

      @dataSchema = @creativeWork.get_data_hash

      #todo: add readonly property
      if @creativeWork.metadata['validation']['name'] != 'Thema'
        render layout: "data_cycle_core/creative_works_edit"
      else
        render layout: "data_cycle_core/creative_works_show"
      end
    end

    def new
      #only for testing
      @creativeWork = DataCycleCore::CreativeWork.new
      set_breadcrumb_for @creativeWork
      render layout: "data_cycle_core/creative_works_show"
    end

    def create

      @creativeWork = create_internal(params[:template])
      set_breadcrumb_for @creativeWork

      if @creativeWork.nil?
        redirect_to :back
        return
      end
      if params[:template] != "Thema"
        if params['parent'].nil? || params['parent'].blank?
          #create new thema
          if params[:template] == "Recherche"
            thema = create_internal("Thema")
            @creativeWork.isPartOf = thema.id unless thema.nil?
          else
            flash[:error] = I18n.t :invalid_parent, scope: [:controllers, :error]
            redirect_to :back
            return
          end
        else
          #set as parent
          @creativeWork.isPartOf = params['parent']
          #get inherit attributes
          inherit_datahash = get_inherit_datahash(@creativeWork)
          if inherit_datahash.nil?
            flash[:error] = I18n.t :invalid_parent_attr, scope: [:controllers, :error]
            redirect_to :back
            return
          end
          @creativeWork.set_data_hash(inherit_datahash)
        end
      end

      #validate ?
      if !@creativeWork.nil? && @creativeWork.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name']
        redirect_to @creativeWork
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

      datahash = DataCycleCore::DataHashService.flatten_datahash_value(creative_work_params[:datahash], @creativeWork.metadata['validation'],false)

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
        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: @creativeWork.metadata['validation']['name']
        
        if Rails.env.development?
          redirect_to edit_creative_work_path(@creativeWork) if Rails.env.development?
        else
          redirect_to @creativeWork
        end

      else
        render 'edit'
      end
    end

    def validate_single_data
      @creativeWork = DataCycleCore::CreativeWork.find(params[:id])
      datahash = DataCycleCore::DataHashService.flatten_datahash_value(creative_work_params[:datahash], @creativeWork.metadata['validation'])
      valid = @creativeWork.validate(datahash)
      render :json => valid.to_json
    end

    private

      def creative_work_params
        datahash = [
          #base data
          :headline,
          :description,
          :text,
          #metadata
          {:validityPeriod => [
            :validFrom,
            :validUntil
          ]},
          #classifications
          {:state => []},
          {:kind => []},
          {:season => []},
          {:topics => []},
          {:markets => []},
          {:tags => []},
          {:outputChannels => []},
          #content
          {:image => []},
          {:video => []},
          :alternativeHeadline,
          :metaTitle,
          :metaDescription,
          :keywords,
          :sameAs,
          :isPartOf,
          #content offer
          :price,
          :service,
          :name,
          {:logo => []},
          {:offerPeriod => [
            {:offerPeriod => 
              [
                :validFrom,
                :validUntil
              ]
            }
          ]},
          {:author => [
            :id
          ]},
          {:contentLocation => [
            :id
          ]},
          {:website => [
            :url,
            :name
          ]},
          #content quotation
          {:quotation => [
            :id,
            :text,
            {:image => []},
            {:author => [
              :id
            ]}
          ]},
          #content portrait - biographie
          {:about => [
            :id
          ]},
          #content mobile application
          {:mobileApplication => [
            :id,
            :url,
            :operatingSystem
          ]},
          #content timeline
          {:timelineItem => [
            :id,
            :headline,
            {:image => []},
            {:contentLocation => [
              :id
            ]},
            {:temporalCoverage => [
              :validFrom,
              :validUntil
            ]},
            :description
          ]},
          #content interview
          {:audio => []},
          #content voting
          {:suggestedAnswer => [
            :text,
            {:image => []}
          ]},
          #content question
          {:acceptedAnswer => [
            :id,
            :text,
            {:image => []}
          ]},
          #content quiz
          {:question => [
            :id,
            :headline,
            :text,
            {:image => []},
            {:suggestedAnswer => [
              :id,
              :text,
              {:image => []}
            ]},
            {:acceptedAnswer => [
              :id,
              :text,
              {:image => []}
            ]},
          ]},
          #content recipe
          :recipeInstructions,
          :recipeYield,
          :totalTime,
          {:recipeCourse => []},
          {:recipeCategory => []},
          :recipeIngredient,
          {:recipeComponent =>[
            :id,
            :recipeInstructions,
            :recipeIngredient,
            :totalTime,
          ]},
          {:event => [
            :id,
            :url,
            {:eventPeriod => [
             :startDate,
             :endDate
            ]},
          ]},
        ]

        params.require(:creative_work).permit(:headline, :datahash => datahash)
        #params.require(:creative_work).permit!
      end

      def is_number? string
        true if Float(string) rescue false
      end

      def create_internal(template)

        creative_work = DataCycleCore::CreativeWork.new(creative_work_params)

        template = DataCycleCore::CreativeWork.where(template: true, headline: template, description: "CreativeWork").first
        validation = template.metadata['validation']

        creative_work.metadata = { 'validation' => validation }
        creative_work.save

        datahash = {'headline' => creative_work_params[:headline], 'creator' => current_user[:id]}

        # unless validation['properties']['data_pool'].nil?
        #   data_pool_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
        #       .where("classification_tree_labels.name = ?", validation['properties']['data_pool']['type_name'])
        #       .where("classification_aliases.name = ?", validation['properties']['data_pool']['default_value']).first

        #   datahash['data_pool'] = [data_pool_classification.id] unless data_pool_classification.nil?
        # end

        # #add data_type
        # unless validation['properties']['data_type'].nil?
        #   data_type_classification = DataCycleCore::Classification.joins(classification_aliases: [classification_trees: [:classification_tree_label]])
        #       .where("classification_tree_labels.name = ?", validation['properties']['data_type']['type_name'])
        #       .where("classification_aliases.name = ?", validation['properties']['data_type']['default_value']).first

        #   datahash['data_type'] = [data_type_classification.id] unless data_type_classification.nil?
        # end

        creative_work.set_data_hash(datahash)

        #validate ?
        if creative_work.save
          return creative_work
        else
          return nil
        end

      end

      def get_inherit_datahash(creativeWork)

        data_hash = creativeWork.get_data_hash
        parent = DataCycleCore::CreativeWork.find_by(id: creativeWork.isPartOf)

        if parent.nil?
          return nil
        end

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

        return data_hash.compact!

      end

      def set_breadcrumb_for creativeWork
        set_breadcrumb_for creativeWork.parent if creativeWork.parent
        add_breadcrumb creativeWork.metadata['validation']['name'], creativeWork.content['headline'], creative_work_path(creativeWork.id)
      end

  end
end
