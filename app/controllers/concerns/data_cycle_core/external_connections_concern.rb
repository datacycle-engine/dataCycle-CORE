# frozen_string_literal: true

module DataCycleCore
  module ExternalConnectionsConcern
    extend ActiveSupport::Concern

    def switch_primary_external_system
      @content = DataCycleCore::Thing.find(switch_system_params[:id])

      authorize! :switch_primary_external_system, @content

      @external_sync = @content.external_system_syncs.find(switch_system_params[:external_system_sync_id])

      begin
        @content.switch_primary_external_system(@external_sync)
        flash[:success] = I18n.t('content_external_data.primary_system_switched', locale: helpers.active_ui_locale)
      rescue ActiveRecord::RecordNotUnique
        existing = DataCycleCore::Thing.find_by(external_source_id: @external_sync.external_system_id, external_key: @external_sync.external_key)
        flash[:error] = I18n.t('content_external_data.duplicate_record_html', url: existing ? thing_path(existing) : nil, locale: helpers.active_ui_locale)
      end

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path) }
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/contents/external_connections', locals: { content: @content }).strip, **flash.discard.to_h } }
      end
    end

    def demote_primary_external_system
      @content = DataCycleCore::Thing.find(switch_system_params[:id])

      authorize! :demote_primary_external_system, @content

      @content.external_source_to_external_system_syncs('duplicate')
      flash[:success] = I18n.t('external_connections.demote_to_sync.success', locale: helpers.active_ui_locale)

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path) }
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/contents/external_connections', locals: { content: @content }).strip, **flash.discard.to_h } }
      end
    end

    def remove_external_connection
      @content = DataCycleCore::Thing.find(params[:id])

      authorize! :remove_external_connection, @content

      if switch_system_params[:external_system_sync_id].present?
        @content.external_system_syncs.find_by(id: switch_system_params[:external_system_sync_id])&.destroy
      else
        @content.update_columns(external_source_id: nil, external_key: nil)
      end

      @content.invalidate_self

      flash.now[:success] = I18n.t('external_connections.remove_external_system_sync.success', locale: helpers.active_ui_locale)

      respond_to do |format|
        format.html { redirect_back(fallback_location: root_path, notice: flash[:success]) }
        format.json { render json: { html: render_to_string(formats: [:html], layout: false, partial: 'data_cycle_core/contents/external_connections', locals: { content: @content }).strip, **flash.discard.to_h } }
      end
    end

    private

    def switch_system_params
      params.permit(:id, :external_system_sync_id)
    end
  end
end
