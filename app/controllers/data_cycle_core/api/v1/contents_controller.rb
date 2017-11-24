module DataCycleCore
  class Api::V1::ContentsController < Api::V1::ApiBaseController

    @@default_per = 50

    def show
      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])
    end

    def update

      content = params[:content]

      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])

      render json: @content.get_data_hash

    end

    def destroy

      @content = Object.const_get("DataCycleCore::#{params[:type].classify}")
        .includes({classifications: [], translations: []})
        .find(params[:id])

      # @content.destroy
      # render json: {"success" => @content.destroyed?}

    end

    def search
      @language = params[:language] unless params[:language].blank?
      @language ||= 'de'

      search_string = (params[:search] || '').split(' ').join('%')
      order_string = "boost * (
      8 * similarity(classification_string,'%#{search_string}%') +
      4 * similarity(headline, '%#{search_string}%') +
      2 * ts_rank_cd(words, plainto_tsquery('simple', '#{(params[:search] || '').squish}'),16) +
      1 * similarity(full_text, '%#{search_string}%'))
      DESC NULLS LAST,
      updated_at DESC"

      classification_aliases = DataCycleCore::ClassificationAlias.joins(
          :classification_tree_label
      ).where(
          classification_trees: {
              classification_tree_label: DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
          },
          name: ['Artikel']
      )

      query = DataCycleCore::Filter::Search.new(@language).where(content_data_type: DataCycleCore::CreativeWork).in_validity_period
      query = query.with_classification_alias_ids(classification_aliases.map(&:id))
      query = query.fulltext_search(params[:search]) unless params[:search].blank?
      query = query.order(order_string)

      @per = params[:per] unless params[:per].blank?
      @per ||= @@default_per

      @total = query.count
      pages = @total.fdiv(@per.to_i).ceil

      unless params[:page].blank?
        @page = params[:page]
        @page = pages if params[:page].to_i > pages
      end
      @page ||= 1

      @contents = query.page(@page).per(@per).map(&:content_data)
    end

    private

    def content_params
      params.permit(:page, :per, :language, :search, :token)
    end

  end
end
