# frozen_string_literal: true

module DataCycleCore
  class PublicationsController < ApplicationController
    include DataCycleCore::Filter
    before_action :authenticate_user! # from devise (authenticate)
    authorize_resource class: false # from cancancan (authorize)

    def index
      @publication_classifications = DataCycleCore::Thing
        .find_by(template: true, template_name: 'Publikations-Plan')
        &.schema
        &.dig('properties')
        &.select { |_, v| v['type'] == 'classification' && (Array(DataCycleCore::ClassificationTreeLabel.find_by(name: v['tree_label'])&.visibility) & ['show', 'show_more']).size.positive? }
        &.map { |k, v| [k, v['tree_label']] }
        &.to_h || {}

      @stored_filter ||= DataCycleCore::StoredFilter.new
      @filters = pre_filters.dup
      @filters.push(
        {
          't' => 'relation',
          'v' => 'publication_schedule'
        }
      )
      @stored_filter.parameters ||= @filters || []
      @stored_filter.parameters&.reject! { |f| f['v'].is_a?(Hash) ? f['v'].all? { |_, v| v.blank? } : f['v'].blank? }
      @language ||= params.fetch(:language) { [current_user.default_locale] }
      @stored_filter.language = @language
      query = @stored_filter.apply

      @filters = @stored_filter.parameters.select { |f| f.key?('c') }.each { |f| f['identifier'] = SecureRandom.hex(10) }
      @selected_classification_aliases = DataCycleCore::ClassificationAlias
        .where(
          id: @filters
            .select { |f|
              f['t'].in?(['classification_alias_ids', 'geo_within_classification']) ||
                (f['t'] == 'advanced_attributes' && f['q'] == 'classification_alias_ids')
            }
            .map { |f| f['v'] }
            .flatten
            .compact
            .uniq
        )
        .includes(:classification_alias_path)
        .index_by(&:id)

      query2 = DataCycleCore::Thing.joins(:content_content_b).where(template: false, template_name: 'Publikations-Plan', content_contents: { content_a_id: query.pluck(:id) })

      value_storage_location = 'metadata'

      if params[:publications_from].present?
        query2 = query2.where("(#{value_storage_location} ->> 'publish_at')::date >= ?", params[:publications_from])
      else
        query2 = query2.where("(#{value_storage_location} ->> 'publish_at')::date >= ?", Date.current)
      end

      query2 = query2.where("(#{value_storage_location} ->> 'publish_at')::date <= ?", params[:publications_until]) if params[:publications_until].present?

      @publication_classification_alias_ids = @filters.select { |f| f['c'] == 'd' && f['t'] == 'classification_alias_ids' && @publication_classifications.values&.include?(f['n']) }

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

      if params[:count_only]
        @content_class = params[:content_class]
        @target = params[:target]
        @count_only = true
        @total_count = query2.includes(:content_content_b).map(&:content_content_b).map { |c| c.first.content_a_id }.size

        render json: { html: helpers.result_count(@count_mode, @total_count, @content_class || 'things') }
      else
        @contents = query2.order(Arel.sql("(#{value_storage_location} ->> 'publish_at')::date ASC")).page(params[:page]).per(10).includes(:classifications, content_content_b: [content_a: :translations])

        @total = @contents.map(&:content_content_b).map { |c| c.first.content_a_id }.uniq.size

        @pages = @contents.total_pages

        respond_to(:html, :js)
      end
    end
  end
end
