# frozen_string_literal: true

module DataCycleCore
  class PublicationsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
      @publication_classifications = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Publikations-Plan')&.schema&.dig('properties')&.select { |k, v| v['type'] == 'classification' && !DataCycleCore.internal_data_attributes.include?(k) }&.map { |k, v| [k, v['tree_label']] }.to_h

      @filters = params[:f].presence&.values&.reject { |f| f['v'].blank? } || []
      @filters.push(
        {
          't' => 'relation',
          'v' => 'publication_schedule'
        }
      )

      @language ||= params.fetch(:language, DataCycleCore.ui_language)
      query = DataCycleCore::Filter::Search.new(@language)

      query = query.fulltext_search(params[:search]) if params[:search].present?

      @filters.presence&.each do |filter|
        query = query.send(filter['t'], filter['v']) if query.respond_to?(filter['t'])
      end

      @default_filters = @filters.select { |f| f['c'] == 'd' && f['t'] == 'classification_alias_ids' }
      @advanced_filters = @filters.select { |f| f['c'] == 'a' }
      @selected_classifications = @default_filters.map { |c| c['v'] }.flatten.compact.uniq
      @selected_classification_aliases = DataCycleCore::ClassificationAlias.select(:id, :name).where(id: @filters.select { |f| f['t'] == 'classification_alias_ids' }.map { |f| f['v'] }.flatten.compact.uniq).map { |c| [c.id, c.name] }.to_h

      query2 = DataCycleCore::CreativeWork.joins(:content_content_b).where(template: false, template_name: 'Publikations-Plan', content_contents: { content_a_id: query.pluck(:content_data_id) })

      # TODO: move to value after final refactor_data_definition migration
      value_storage_location = 'metadata'

      if params[:publications_from].present?
        query2 = query2.where("(#{value_storage_location} ->> 'publish_at')::timestamptz >= ?", params[:publications_from])
      else
        query2 = query2.where("(#{value_storage_location} ->> 'publish_at')::timestamptz >= ?", Date.current)
      end

      query2 = query2.where("(#{value_storage_location} ->> 'publish_at')::timestamptz <= ?", params[:publications_until]) if params[:publications_until].present?

      @publication_classification_alias_ids = @default_filters.select { |f| @publication_classifications.values&.include?(f['n']) }

      if @publication_classification_alias_ids.present?
        content_ids = []
        @publication_classification_alias_ids.each_with_index do |alias_ids, index|
          if index.zero?
            content_ids = query2.with_classification_alias_ids(alias_ids['v']).pluck(:id)
          else
            content_ids &= query2.with_classification_alias_ids(alias_ids['v']).pluck(:id)
          end
        end

        query2 = query2.where(id: content_ids)
      end

      @contents = query2.order("(#{value_storage_location} ->> 'publish_at')::timestamptz ASC").page(params[:page]).per(10).includes(:classifications, content_content_b: [content_a: :translations])

      @total = @contents.map(&:content_content_b).map { |c| c.first.content_a_id }.uniq.size

      @pages = @contents.total_pages

      respond_to(:html, :js)
    end
  end
end
