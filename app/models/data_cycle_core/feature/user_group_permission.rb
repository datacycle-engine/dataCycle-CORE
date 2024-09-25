# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserGroupPermission < Base
      class << self
        def attribute_keys(content = nil)
          Array.wrap(configuration(content).dig('attribute_keys')&.keys)
        end

        def abilities(content = nil, view = nil)
          return [] if view.nil?

          relations = configuration(content).dig('abilities')
          permission_list = []

          relations.each do |resource, details|
            permission_list << create_permission_option(resource, content.name, details, view.active_ui_locale)
          end
          permission_list.sort_by { |a| a[0] }
        end

        private

        def create_permission_option(resource, group_name, details, active_ui_locale = 'de')
          return if group_name.nil? || details.nil? || details['actions'].nil? || details['segment'].nil?

          actions = details['actions']
          segment = details['segment']
          templates = details['parameters'].present? && details['parameters'].size > 1 ? Array.wrap(details['parameters'][1]) : []
          param_segment = DataCycleCore::Abilities::Segments.const_get(segment).new

          subject_name = param_segment.to_h[:@subject].model_name.human(count: 1, locale: active_ui_locale)
          template_names = templates.present? ? "(#{templates.join(', ')})" : ''
          action_names = actions.map { |action| I18n.t("abilities.actions.#{action}", locale: active_ui_locale) }.join(', ')

          display_name = "#{subject_name} #{template_names} > #{action_names}"

          identifier = resource
          [display_name, identifier]
        end
      end
    end
  end
end
