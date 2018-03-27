module DataCycleCore
  class PublicationsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
      @publication_classifications = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Publikations-Plan')&.schema&.dig('properties')&.select { |k, v| v['type'] == 'classificationTreeLabel' && !DataCycleCore.internal_data_attributes.include?(k) }&.map { |k, v| [k, v['type_name']] }.to_h

      @classification_array ||= []

      @classification_array.push(*params[:classification]&.map { |c| c[:selected] }&.flatten)

      query = DataCycleCore::Filter::Search.new(params.fetch(:language, 'de')).in_validity_period

      query = query.with_relation('publication_schedule')

      query = query.fulltext_search(params[:search]) if params[:search].present?

      @with_classification_alias_ids = parse_classifications(@classification_array) if @classification_array.present?
      @with_classification_alias_ids.presence&.each_value do |class_array|
        query = query.with_classification_alias_ids(class_array)
      end

      query2 = DataCycleCore::CreativeWork.joins(:content_content_b).where(template: false, template_name: 'Publikations-Plan', content_contents: { content_a_id: query.pluck(:content_data_id) })

      if params[:publications_from].present?
        query2 = query2.where("(metadata ->> 'publish_at')::timestamptz >= ?", params[:publications_from])
      else
        query2 = query2.where("(metadata ->> 'publish_at')::timestamptz >= ?", Date.current)
      end

      query2 = query2.where("(metadata ->> 'publish_at')::timestamptz <= ?", params[:publications_until]) if params[:publications_until].present?

      @publication_classification_alias_ids = @with_classification_alias_ids&.select { |k, _| @publication_classifications.values&.include?(k) }

      if @publication_classification_alias_ids.present?
        content_ids = []
        @publication_classification_alias_ids.each_with_index do |(_, class_array), index|
          if index.zero?
            content_ids = query2.with_classification_alias_ids(class_array).pluck(:id)
          else
            content_ids &= query2.with_classification_alias_ids(class_array).pluck(:id)
          end
        end
        query2 = query2.where(id: content_ids)
      end

      @contents = query2.order("(metadata ->> 'publish_at')::timestamptz ASC").page(params[:page]).per(10).includes(:classifications, content_content_b: [content_a: :translations])

      @total = @contents.map(&:content_content_b).map { |c| c.first.content_a_id }.uniq.size

      @pages = @contents.total_pages

      respond_to(:html, :js)
    end
  end
end
