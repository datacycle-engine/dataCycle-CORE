module DataCycleCore
  class RechercheController < ApplicationController
    before_action :authenticate_user!   # from devise (authenticate)
    #load_and_authorize_resource         # from cancancan (authorize)

    # GET /recherche/1
    def show
    end

    # GET /recherche/new
    def new
      @datahash = params[:datahash]
      @datahash ||= {}
      if !params[:headline].blank? && @datahash[:headline].blank?
        @datahash["headline"] = params[:headline]
      end

      @language = params[:language]
      @language ||= "de" #default-language

      template = DataCycleCore::CreativeWork.where(template: true, headline: "Recherche", description: "CreativeWork").first
      validation = template.metadata['validation']
      @recherche = DataCycleCore::CreativeWork.new
      @recherche.metadata = {"validation" => validation}
      @recherche.set_data_hash(@datahash)

      @data = @recherche.get_data_type
      @dataSchema = @recherche.get_data_hash
    end

    # GET /recherche/1/edit
    def edit
    end

    # POST /recherche
    def create
    end

    # PATCH/PUT /recipes/1
    def update
    end

    private

      def recherche_params
        params.require(:recherche).permit(:headline, :datahash => [:headline, :text, image: [], video: []])
      end

  end
end
