module DataCycleCore
  class Api::V1::EventsController < DataCycleCore::Api::V1::ContentsController
    def index
      query = Event.includes(:translations, :classifications)
        .with_classification_alias_names(DataCycleCore.allowed_content_api_classifications)
        .with_translations(params.fetch(:language, 'de'))

      query = query.where(Event.arel_table[:end_date].gteq(Time.zone.now))

      if params.dig(:filter, :classifications)
        query = query.with_classification_alias_ids(params.dig(:filter, :classifications).split(',').map(&:strip))
      end

      query = query.sort_by_proximity

      @total = query.count

      @contents = apply_paging(query)

      render 'search'
    end

    def show
      @content = Event.includes(:classifications, :translations).find(params[:id])
    end

    def permitted_parameter_keys
      super + [{ filter: :classifications }]
    end
  end
end
