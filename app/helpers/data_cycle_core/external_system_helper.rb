# frozen_string_literal: true

module DataCycleCore
  module ExternalSystemHelper
    def external_systems_tooltip(external_source, external_system_syncs)
      tooltip_lines = []
      tooltip_lines << ">- #{external_source.name}" unless external_source.nil?

      external_system_syncs.each do |s|
        tooltip_lines << "#{external_sync_status_icon(s.status, s.sync_type)} #{s.external_system&.name}" unless s.external_system.nil?
      end

      tooltip_lines.join("\n")
    end

    def external_systems_with_details(content)
      syncs = {}

      unless content.external_source.nil?
        syncs[content.external_source.name] = [{
          status: 'success',
          sync_type: 'import',
          date: [content.updated_at, content.external_source.last_successful_import].compact.min,
          external_key: content.external_key,
          name: nil
        }]
      end

      content.external_system_syncs.includes(:external_system).each do |sync|
        (syncs[sync.external_system.name] ||= []).push({
          status: sync.status,
          sync_type: sync.sync_type,
          date: sync.last_successful_sync_at,
          external_key: sync.external_key,
          name: sync.data&.dig('external_name')
        })
      end

      syncs
    end

    def external_sync_status_icon(status, sync_type, include_status_message = false)
      icon = case sync_type
             when 'import' then '⇥'
             when 'export' then '↦'
             else '–'
      end

      icon = '⟳' if status == 'pending'
      icon = '☓' if status&.in?(['failure', 'error'])

      return icon unless include_status_message

      tag.span(icon, title: ("#{t('common.status', locale: DataCycleCore.ui_language)}: #{t("external_connection_states.#{status}", locale: DataCycleCore.ui_language)}" if status.present?))
    end
  end
end
