# frozen_string_literal: true

module DataCycleCore
  class UserGroupsController < ApplicationController
    load_and_authorize_resource         # from cancancan (authorize)
    before_action :set_user_group, only: [:edit, :update, :destroy]

    def index
      @search_param = search_params[:q]

      query = DataCycleCore::UserGroup.all

      search_columns = DataCycleCore::UserGroup.columns
        .select { |c| c.type == :string }
        .map(&:name)

      if @search_param.present?
        search_term = @search_param.split(' ').map { |item| "concat_ws(' ', #{search_columns.join(', ')}) ILIKE '%#{item.strip}%'" }.join(' AND ')
        query = query.where(search_term)
      end

      @contents = query.includes(:users).order(:name).page(params[:page])

      if count_only_params[:count_only].present?
        @count_only = true
        @target = count_only_params[:target]
        @total_count = @contents.total_count
        @count_mode = count_only_params[:count_mode]
        @content_class = count_only_params[:content_class]
      end

      respond_to do |format|
        format.html
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/application/count_or_more_results').squish } }
      end
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

    def edit
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
      params.require(:user_group).permit(:name, user_ids: [], classification_ids: [])
    end

    def set_user_group
      @user_group = DataCycleCore::UserGroup.find(params[:id])
    end

    def count_only_params
      params.permit(:target, :count_only, :count_mode, :content_class)
    end
  end
end
