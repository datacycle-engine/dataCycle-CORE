module DataCycleCore
  class Api::V1::EventsController < DataCycleCore::Api::V1::ContentsController
    def index
      query = Event.with_classification_alias_names(DataCycleCore.allowed_content_api_classifications)

      if params&.dig(:filter, :from)
        query = query.where(Event.arel_table[:end_date].gteq(DateTime.parse(params&.dig(:filter, :from))))
      else
        query = query.where(Event.arel_table[:end_date].gteq(Time.zone.now))
      end

      if params&.dig(:filter, :to)
        query = query.where(Event.arel_table[:start_date].lteq(DateTime.parse(params&.dig(:filter, :to))))
      end

      if params&.dig(:filter, :classifications)
        params.dig(:filter, :classifications).map { |classifications|
          classifications.split(',').map(&:strip).reject(&:blank?)
        }.reject(&:empty?).each do |classifications|
          query = query.with_classification_alias_ids(classifications)
        end
      end

      query = query.with_translations(params.fetch(:language, 'de'))

      @total = query.count

      query = query.includes(:translations, :classifications).sort_by_proximity

      @contents = apply_paging(query)

      render 'search'
    end

    def show
      @content = Event.includes(:classifications, :translations).find(params[:id])
    end

    def permitted_parameter_keys
      super + [{ filter: [:from, :to, { classifications: [] }] }]
    end
  end
end
