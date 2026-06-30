# frozen_string_literal: true

module DataCycleCore
  # SECURITY (DC-01): `ApplicationController#remote_render` lets an authenticated caller name a
  # partial OR a helper method that the server then renders / invokes (via `try`) with
  # attacker-controlled locals. Unbounded, this is a generic "render any template / call any
  # helper" primitive — the vector behind the admin-panel record dump (GHSA-xc6g / CVE-2026-32806).
  #
  # This concern constrains both inputs to an allowlist. Every client call pattern
  # (`data-remote-path`, `data: { remote_path: }`, `data-remote-render-function`,
  # `data: { remote_render_function: }`) is funnelled by remote_renderer.js into the same two
  # controller params, so enforcing at this single sink covers all of them.
  #
  # DEVELOPERS: prefer a native, authorized Turbo frame over remote_render for anything new, and
  # especially for anything that touches sensitive data. A Turbo frame is a normal controller action
  # that loads its own subject and runs `authorize!` BEFORE rendering (see DataCycleCore::AdminPanelActions,
  # modelled on the dash_board pg_stats frame) — loading and authorization stay on the server where
  # they belong. remote_render, by contrast, resolves attacker-controlled {class,id} params into live
  # records (ParamsResolver) with NO object-level authorization, so every partial it can reach must
  # treat its locals as hostile. Only extend the allowlist below for genuinely public, authorization-free
  # view fragments; if a fragment needs auth or per-record loading, build a Turbo frame instead.
  module RemoteRenderGuard
    extend ActiveSupport::Concern

    # Exact partial paths reachable via remote_render. Admin-panel partials are deliberately
    # ABSENT: each tab is served by its own authorized Turbo-frame action
    # (DataCycleCore::AdminPanelActions), never through this generic endpoint.
    ALLOWED_PARTIALS = [
      'data_cycle_core/application/compare_sources_dropdown',
      'data_cycle_core/application/downloads/forms/content',
      'data_cycle_core/application/downloads/forms/indesign',
      'data_cycle_core/application/downloads/forms/zip',
      'data_cycle_core/application/histories',
      'data_cycle_core/application/new_contents/new_content_links',
      'data_cycle_core/application/watch_lists/editable_link_collection',
      'data_cycle_core/application/watch_lists/readable_link_collection',
      'data_cycle_core/classifications/classification_alias_form',
      'data_cycle_core/classifications/classification_alias_removal_warning',
      'data_cycle_core/classifications/classification_polygon_map',
      'data_cycle_core/classifications/classification_tree_label_form',
      'data_cycle_core/classifications/classification_tree_label_removal_warning',
      'data_cycle_core/classifications/concept_scheme_link_reveal',
      'data_cycle_core/classifications/concept_scheme_link_warning',
      'data_cycle_core/classifications/translated_form_fields',
      'data_cycle_core/contents/editors/embedded/single_item',
      'data_cycle_core/contents/external_connections/new_external_connection_form',
      'data_cycle_core/contents/grid/attributes/warnings',
      'data_cycle_core/contents/preview_link',
      'data_cycle_core/contents/related',
      'data_cycle_core/contents/viewers/embedded/default',
      'data_cycle_core/contents/viewers/embedded/image_variant',
      'data_cycle_core/data_links/form',
      'data_cycle_core/duplicate_candidates/duplicates_list',
      'data_cycle_core/external_systems/new',
      'data_cycle_core/object_browser/editor_overlay',
      'data_cycle_core/reports/form',
      'data_cycle_core/stored_filters/edit_form',
      'data_cycle_core/stored_filters/search_favorites_short',
      'data_cycle_core/stored_filters/search_history_short'
    ].to_set.freeze

    # Dynamic partial families whose leaf name is derived from server data (template names,
    # attribute keys) and therefore cannot be enumerated exactly.
    ALLOWED_PARTIAL_PREFIXES = [
      'data_cycle_core/contents/new/',
      'data_cycle_core/contents/grid/compact/attributes/'
    ].freeze

    # Helper methods invokable via render_function (rendered through `try`).
    ALLOWED_FUNCTIONS = [
      'advanced_graph_filter_advanced_type',
      'render_content_tile_details',
      'render_linked_partial',
      'render_specific_translatable_attribute_editor',
      'render_specific_translatable_attribute_viewer',
      'render_specific_translatable_title_attribute_viewer'
    ].to_set.freeze

    # A view path: lowercase alphanumerics + underscores, slash-separated. The absence of dots
    # blocks both path traversal (`..`) and file extensions; no leading/trailing slash blocks
    # absolute paths.
    PARTIAL_FORMAT = %r{\A[a-z0-9_]+(/[a-z0-9_]+)*\z}

    private

    def remote_render_function_allowed?(function)
      return false if function.blank?

      ALLOWED_FUNCTIONS.include?(function) ||
        DataCycleCore.additional_remote_render_functions.include?(function)
    end

    def remote_render_partial_allowed?(partial)
      return false if partial.blank? || !partial.match?(PARTIAL_FORMAT)
      return true if ALLOWED_PARTIALS.include?(partial) ||
                     DataCycleCore.additional_remote_render_partials.include?(partial)

      (ALLOWED_PARTIAL_PREFIXES + DataCycleCore.additional_remote_render_partial_prefixes)
        .any? { |prefix| partial.start_with?(prefix) }
    end
  end
end
