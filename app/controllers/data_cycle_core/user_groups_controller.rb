# frozen_string_literal: true

module DataCycleCore
  class UserGroupsController < ApplicationController
    load_and_authorize_resource # from cancancan (authorize)
    before_action :set_user_group, only: [:edit, :update, :destroy]

    def index
      query = DataCycleCore::UserGroup.all

      @filters = filter_params
      @filters&.select { |f| f.key?('c') }&.each { |f| f['identifier'] = SecureRandom.hex(10) }

      @filters&.each do |filter|
        filter_method = (filter['c'] == 'd' ? filter['n'] : filter['t']).dup
        filter_method = "#{filter['t']}_#{filter['n']}" if filter['c'] == 'a' && query.respond_to?(:"#{filter['t']}_#{filter['n']}")
        filter_method.prepend(DataCycleCore::StoredFilterExtensions::FilterParamsHashParser::FILTER_PREFIX[filter['m']].to_s)

        next unless query.respond_to?(filter_method)

        query = query.send(filter_method, filter['v'])
      end

      @sort_params = sort_params
      if @sort_params.present?
        query = query.order(*@sort_params.map { |s| { s[:m].to_sym => s[:o].to_sym } })
      else
        query = query.order(:name)
      end

      @mode = mode_params[:mode].in?(['list', 'tree', 'map']) ? mode_params[:mode].to_s : 'grid'
      @contents = query.includes(:users).page(params[:page])

      if count_only_params[:count_only].present?
        @count_only = true
        @target = count_only_params[:target]
        @total_count = @contents.total_count
        @count_mode = count_only_params[:count_mode]
        @content_class = count_only_params[:content_class]
      end

      respond_to do |format|
        format.html
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').strip } }
      end
    end

    def edit
    end

    def create
      @user_group = DataCycleCore::UserGroup.new(user_group_params)

      if @user_group.save
        flash[:success] = I18n.t :created, scope: [:controllers, :success], data: DataCycleCore::UserGroup.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale
      else
        flash[:error] = @user_group.try(:errors).try(:first).try(:[], 1)
      end

      redirect_back(fallback_location: root_path)
    end

    def update
      if @user_group.update(user_group_params)

        flash[:success] = I18n.t :updated, scope: [:controllers, :success], data: DataCycleCore::UserGroup.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale

        if Rails.env.development?
          redirect_to edit_user_group_path(@user_group)
        else
          redirect_to user_groups_path
        end

      else
        render 'edit'
      end
    end

    def destroy
      if @user_group.destroy
        flash[:success] = I18n.t :destroyed, scope: [:controllers, :success], data: DataCycleCore::UserGroup.model_name.human(locale: helpers.active_ui_locale), locale: helpers.active_ui_locale
      else
        flash[:error] = @user_group.try(:errors).try(:first).try(:[], 1)
      end
      redirect_back(fallback_location: root_path)
    end

    private

    def search_params
      params.permit(:q)
    end

    def user_group_params
      ug_params = params.require(:user_group).permit(:name, user_ids: [], classification_ids: [], shared_collection_ids: [], permissions: [])

      ug_params[:user_ids]&.compact_blank!
      ug_params[:classification_ids]&.compact_blank!
      ug_params[:shared_collection_ids]&.compact_blank!
      ug_params[:permissions]&.compact_blank!

      ug_params
    end

    def set_user_group
      @user_group = DataCycleCore::UserGroup.find(params[:id])
    end

    def count_only_params
      params.permit(:target, :count_only, :count_mode, :content_class)
    end

    def sort_params
      params.permit(s: {}).to_h[:s].presence&.values&.reject { |s| DataCycleCore::DataHashService.blank?(s) }
    end

    def mode_params
      params.permit(:mode)
    end

    def filter_params
      params.permit(f: {}).to_h[:f].presence&.values&.reject { |f| DataCycleCore::DataHashService.blank?(f) || DataCycleCore::DataHashService.blank?(f['v']) }
    end
  end
end
