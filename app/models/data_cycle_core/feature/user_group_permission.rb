# frozen_string_literal: true

module DataCycleCore
  module Feature
    class UserGroupPermission < Base
      class << self
        def attribute_keys(content = nil)
          Array.wrap(configuration(content).dig('attribute_keys')&.keys)
        end

        def ability_selection(view = nil)
          return [] if view.nil?

          relations = configuration.dig('abilities')
          permission_list = []

          relations.each do |resource, details|
            permission_list << create_permission_option(resource, details, view.active_ui_locale)
          end
          permission_list.sort_by { |a| a[0] }
        end

        def abilities
          configuration&.dig('abilities') || {}
        end

        def default_role
          role = configuration&.dig('default_role')
          return role if role == 'all'
          role.to_sym
        end

        def reload
          super

          DataCycleCore::Abilities::PermissionsList.reload

          self
        end

        private

        def create_permission_option(resource, details, active_ui_locale = 'de')
          return if details.nil? || details['actions'].nil?

          actions = details['actions']

          subject_name = DataCycleCore::Thing.model_name.human(count: 1, locale: active_ui_locale)
          action_names = actions.map { |action| I18n.t("abilities.actions.#{action}", locale: active_ui_locale) }.join(', ')

          display_name = "#{subject_name} > #{action_names}"

          identifier = resource
          [display_name, identifier]
        end
      end
    end
  end
end
