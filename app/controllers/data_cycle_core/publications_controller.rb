# frozen_string_literal: true

module DataCycleCore
  class PublicationsController < ApplicationController
    include DataCycleCore::FilterConcern
    authorize_resource class: false # from cancancan (authorize)
    before_action :check_feature_enabled

    def index
      @publication_classifications = DataCycleCore::ThingTemplate
        .find_by(template_name: 'Publikations-Plan')
        &.schema
        &.dig('properties')
        &.select { |_, v| v['type'] == 'classification' && (Array(DataCycleCore::ClassificationTreeLabel.find_by(name: v['tree_label'])&.visibility) & ['show', 'show_more']).size.positive? }
        .to_h { |k, v| [k, v['tree_label']] }

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
            .pluck('v')
            .flatten
            .compact
            .uniq
        )
        .includes(:classification_alias_path)
        .index_by(&:id)

      query2 = DataCycleCore::Thing.joins(:content_content_b).where(template_name: 'Publikations-Plan', content_contents: { content_a_id: query.pluck(:id) })

      query2 = query2.where("(things.metadata ->> 'publish_at')::date >= ?", params[:publications_from].presence || Date.current)

      query2 = query2.where("(things.metadata ->> 'publish_at')::date <= ?", params[:publications_until]) if params[:publications_until].present?

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
        @total_count = query2.size

        render json: { html: helpers.result_count(@count_mode, @total_count, @content_class || 'things') }
      else
        @contents = query2.order(Arel.sql("(things.metadata ->> 'publish_at')::date ASC")).page(params[:page]).per(25).includes(:classifications, content_content_b: [content_a: :translations]).without_count

        @last_page = @contents.last_page?

        respond_to do |format|
          format.html
          format.json do
            render json: {
              html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/publications/publication_list', locals: { contents: @contents }).strip,
              last_page: @last_page
            }
          end
        end
      end
    end

    private

    def check_feature_enabled
      raise ActiveRecord::RecordNotFound unless DataCycleCore::Feature::PublicationSchedule.enabled?
    end
  end
end
