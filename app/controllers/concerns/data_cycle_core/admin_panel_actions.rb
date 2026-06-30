# frozen_string_literal: true

module DataCycleCore
  # SECURITY (DC-01): the content admin-panel tabs are served as authorized, lazily-loaded Turbo
  # frames (modelled on the dash_board pg_stats frame), never through the generic remote_render
  # endpoint. Each tab is its own action so the data it exposes is built — and reviewable — here in
  # the controller rather than in a view. The shared before_action loads the Thing and runs
  # `authorize! :show_admin_panel` once per request, replacing the former per-partial guards.
  module AdminPanelActions
    extend ActiveSupport::Concern

    PANELS = [
      'schema', 'template_path', 'datahash', 'thing_history_links', 'json_api',
      'meta_data', 'data_export', 'data_send', 'data_job'
    ].freeze

    DATAHASH_ATTRIBUTES = [:external_key, :external_source_id, :created_at, :created_by, :updated_at, :cache_valid_since, :updated_by].freeze
    DATA_EXPORT_ATTRIBUTES = [:exported_data, :exception_data, :status, :last_sync_at, :last_successful_sync_at, :job_id, :job_status, :seen_at].freeze

    included do
      before_action :load_admin_panel_content, only: PANELS.map { |panel| :"admin_panel_#{panel}" }
    end

    # Tab: the content template's sorted schema.
    def admin_panel_schema
      render_admin_panel(@content.thing_template.schema_sorted)
    end

    # Tab: the content template's attribute template paths.
    def admin_panel_template_path
      render_admin_panel(@content.thing_template.template_paths)
    end

    # Tab: the content's stored data hash (system metadata + property values) in the requested locale.
    def admin_panel_datahash
      render_admin_panel(with_admin_panel_locale do
        @content.as_json(only: DATAHASH_ATTRIBUTES).merge(@content.get_data_hash || {})
      end)
    end

    # Tab: links from this content to its history records.
    def admin_panel_thing_history_links
      render_admin_panel(with_admin_panel_locale do
        @content.thing_history_links.includes(:thing_history).map do |link|
          { thing_id: link.thing_history.thing_id, thing_history_id: link.thing_history.id }
        end
      end)
    end

    # Tab: the content rendered through the v4 JSON API.
    def admin_panel_json_api
      render_admin_panel_json(
        DataCycleCore::ApiRenderer::ThingRendererV4.new(content: @content, language: [I18n.locale.to_s]).render(:json) || {}.to_json
      )
    end

    # Tab: the asset's embedded file metadata, if any. `try` because non-asset content types
    # do not respond to #asset (the tab is hidden for them, but the action stays directly routable).
    def admin_panel_meta_data
      render_admin_panel(@content.try(:asset)&.metadata&.to_utf8 || {})
    end

    # Tab: the content's outbound external-system export syncs.
    def admin_panel_data_export
      render_admin_panel_json(
        @content.external_system_syncs.export.includes(:external_system).to_json(
          only: DATA_EXPORT_ATTRIBUTES,
          include: { external_system: { only: [:id, :name, :identifier] } }
        )
      )
    end

    # Tab: the DZT "data_send" export payload, if present.
    def admin_panel_data_send
      render_admin_panel(dzt_export_data('data_send'))
    end

    # Tab: the DZT "job_result" export status, if present.
    def admin_panel_data_job
      render_admin_panel(dzt_export_data('job_result'))
    end

    private

    def load_admin_panel_content
      @content = DataCycleCore::Thing.find(params[:id])
      authorize!(:show_admin_panel, @content)
      @admin_panel_frame = "#{action_name}_#{@content.id}"
    end

    # Most tabs serialize a Ruby object; json_api / data_export already produce a JSON string and
    # use render_admin_panel_json directly. A nil payload renders an empty frame (e.g. no DZT data).
    def render_admin_panel(data)
      render_admin_panel_json(data&.to_json)
    end

    def render_admin_panel_json(json)
      @admin_panel_data_json = json
      render 'data_cycle_core/contents/admin_panel', layout: false
    end

    def with_admin_panel_locale(&)
      I18n.with_locale(@content.first_available_locale(params[:locale].presence), &)
    end

    def dzt_export_data(key)
      dzt_sync = @content.external_system_syncs.joins(:external_system).find_by(
        "external_systems.identifier = 'dzt' OR external_systems.identifier ILIKE 'onlim%' OR external_systems.identifier ILIKE 'dzt%'"
      )
      dzt_sync&.data&.dig(key)
    end
  end
end
