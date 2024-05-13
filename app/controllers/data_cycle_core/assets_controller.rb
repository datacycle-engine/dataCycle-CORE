# frozen_string_literal: true

module DataCycleCore
  class AssetsController < ApplicationController
    def index
      if permitted_params[:html_target].present?
        @html_target = permitted_params[:html_target]
        @selected = permitted_params[:selected]
        @append = permitted_params[:append] || false
        @page = (permitted_params[:page] || 1).to_i
        @last_asset_type = permitted_params[:last_asset_type]
        @assets = DataCycleCore::Asset.includes(:thing).accessible_by(current_ability).order(type: :asc, updated_at: :desc)
        @assets = @assets.where(type: permitted_params[:types]) if permitted_params[:types].present?
        @assets = @assets.where(id: permitted_params[:asset_ids]) if permitted_params[:asset_ids].present?
        @assets = @assets.limit(25).offset((@page - 1) * 25 - permitted_params[:delete_count].to_i)

        @asset_details = @assets.includes(file_attachment: :blob).map do |a|
          a.as_json(only: [:id, :name, :file_size, :content_type, :file], methods: :duplicate_candidates)
           .merge(a.warnings? ? { 'warning' => a.full_warnings(helpers.active_ui_locale) } : {})
        end
        @total = @assets.except(:limit, :offset).count

        render json: {
          assets: @asset_details || [],
          selected: @selected || [],
          last_asset_type: @assets.last&.type&.to_s,
          page: @page,
          total: @total,
          append: @append,
          html: render_to_string(formats: [:html], layout: false)
        }
      else
        render json: DataCycleCore::Asset.where(type: permitted_params[:type]).accessible_by(current_ability).order(name: :asc).pluck(:name, :id)
      end
    end

    def create
      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: helpers.active_ui_locale) }) && return if asset_params[:file].blank? || asset_params[:type].blank?

      object_type = DataCycleCore.asset_objects.find { |a| a == asset_params[:type] }

      render(json: { error: I18n.t(:wrong_content_type, scope: [:controllers, :error], locale: helpers.active_ui_locale) }) && return if object_type.blank?

      authorize! :create, object_type.constantize

      @asset = object_type.constantize.new(asset_params)
      @asset.name = asset_params[:file].original_filename if asset_params[:name].blank?
      @asset.creator_id = current_user.try(:id)

      begin
        if @asset.save
          render json: @asset.attributes.merge(duplicateCandidates: Array.wrap(@asset.try(:duplicate_candidates)&.as_json(only: [:id], methods: :thumbnail_url))).merge(@asset.warnings? ? { 'warning' => @asset.full_warnings(helpers.active_ui_locale) } : {})
        else
          render(json: {
            error: @asset
              .errors
              .map { |e|
                e.options.present? ? "#{@asset.class.human_attribute_name(e.attribute, locale: helpers.active_ui_locale)} #{DataCycleCore::LocalizationService.translate_and_substitute(e.options, helpers.active_ui_locale)}" : I18n.with_locale(helpers.active_ui_locale) { e.message }
              }
              .flatten
              .join(', ')
          })
        end
      rescue StandardError => e
        render(json: { error: I18n.t('validation.errors.asset_convert', locale: helpers.active_ui_locale), errorDetail: e.message }, status: :unprocessable_entity)
      end
    end

    def update
      return if asset_params[:file].blank?

      @asset = DataCycleCore::Asset.find(params[:id])

      authorize! :update, @asset

      if @asset.update(asset_params)
        render json: @asset.as_json(only: [:id, :name, :file_size, :content_type], methods: :duplicate_candidates)
      else
        render(json: {
          error: @asset
          .errors
          .map { |e|
            e.options.present? ? "#{@asset.class.human_attribute_name(e.attribute, locale: helpers.active_ui_locale)} #{DataCycleCore::LocalizationService.translate_and_substitute(e.options, helpers.active_ui_locale)}" : I18n.with_locale(helpers.active_ui_locale) { e.message }
          }
          .flatten
          .join(', ')
        })
      end
    end

    def find
      authorize! :show, DataCycleCore::TextFile

      @duplicate = DataCycleCore::TextFile.accessible_by(current_ability, :update).find_by('type = ? AND name ILIKE ?', 'DataCycleCore::TextFile', find_params[:q])

      render json: @duplicate&.attributes
    end

    def destroy
      @asset = DataCycleCore::Asset.find(params[:id])

      authorize! :destroy, @asset

      @asset.destroy
    end

    def destroy_multiple
      assets = DataCycleCore::Asset.where(id: permitted_params[:selected])

      assets.each { |a| authorize! :destroy, a }

      # assets.delete_all
      assets.destroy_all
    end

    def destroy_all
      assets = DataCycleCore::Asset.includes(:thing).accessible_by(current_ability)
      ids = assets.map(&:id)

      assets.each { |a| authorize! :destroy, a }

      assets.destroy_all
      render json: { deleted: ids, total: ids.count }
    end

    def duplicate
      @asset = DataCycleCore::Asset.find(permitted_params[:id])
      @duplicate = @asset.duplicate
      @html_target = permitted_params[:html_target]
    end

    private

    def asset_params
      params.require(:asset).permit(:id, :name, :file, :type)
    end

    def permitted_params
      params.permit(:id, :append, :last_asset_type, :page, :delete_count, :type, :html_target, :variant, asset_ids: [], selected: [], types: [])
    end

    def find_params
      params.permit(:q)
    end
  end
end
