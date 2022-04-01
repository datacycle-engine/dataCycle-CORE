# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemHelper
    def external_systems_tooltip(external_source, external_system_syncs)
      external_connections = external_system_syncs&.joins(:external_system)&.select('external_systems.name')&.group('external_systems.name')&.size || {}
      external_connections[external_source.name] = (external_connections[external_source.name] || 0) + 1 unless external_source.nil?

      external_connections.map { |k, v| v > 1 ? "#{k} (#{v})" : k }.compact.uniq.join('<br>')
    end

    def external_systems_with_details(content)
      syncs = {}

      unless content.external_source.nil?
        syncs[content.external_source.name] = [{
          status: 'success',
          sync_type: 'import',
          date: [content.updated_at, content.external_source.last_successful_import].compact.min,
          external_key: content.external_key || content.id,
          external_detail_url: content.external_source.external_detail_url(content),
          external_edit_url: content.external_source.external_url(content),
          title: "#{t('common.external_key', locale: active_ui_locale)}: #{content.external_key || content.id}"
        }]
      end

      content.external_system_syncs.includes(:external_system).each do |sync|
        (syncs[sync.external_system.name] ||= []).push({
          status: sync.status,
          sync_type: sync.sync_type,
          date: sync.last_successful_sync_at,
          external_key: sync.external_key || content.id,
          external_edit_url: sync.external_url,
          external_detail_url: sync.external_detail_url,
          sync_locale: sync.data&.dig('pull_data', 'inLanguage')&.upcase,
          name: sync.data&.dig('name').present? ? [sync.data.dig('pull_data', 'inLanguage')&.upcase, sync.data.dig('name')].compact.join(': ') : nil,
          title: [
            sync.data&.dig('name').present? ? "#{t('common.external_name', locale: active_ui_locale)}: #{sync.data['name']}" : nil,
            sync.data&.dig('alternate_name').present? ? "#{t('common.external_alternate_name', locale: active_ui_locale)}: #{sync.data['alternate_name']}" : nil,
            sync.data&.dig('pull_data', 'inLanguage').present? ? "#{t('common.external_locale', locale: active_ui_locale)}: #{t("locales.#{sync.data.dig('pull_data', 'inLanguage')}", locale: active_ui_locale)}" : nil,
            "#{t('common.external_key', locale: active_ui_locale)}: #{sync.external_key || content.id}"
          ].compact.join("\n\n")
        })
      end

      syncs
    end

    def external_sync_status_icon(status, sync_type, include_status_message = false)
      additional_classes = "external-system-icon #{status}"
      icon = case sync_type
             when 'import', 'export'
               tag.span(
                 tag.i(class: 'fa fa-file-o') +
                 tag.i(class: 'fa fa-long-arrow-right'),
                 class: "fa-stack #{sync_type} #{additional_classes}"
               )
             when 'duplicate'
               tag.i(class: "fa fa-clone #{additional_classes}")
             else tag.i(class: "fa fa-link #{additional_classes}")
             end

      icon = tag.i(class: "fa fa-refresh #{additional_classes}") if status == 'pending'
      icon = tag.i(class: "fa fa-times #{additional_classes}") if status&.in?(['failure', 'error'])

      return icon unless include_status_message

      tag.span(icon, data: { dc_tooltip: ("#{t('common.status', locale: active_ui_locale)}: #{t("external_connection_states.#{status}", locale: active_ui_locale)}" if status.present?) })
    end
  end
end
