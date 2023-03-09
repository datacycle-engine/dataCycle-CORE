# frozen_string_literal: true

module DataCycleCore
  module Content
    HISTORY_LIST_ARGUMENTS = {
      item: nil,
      user: nil,
      locales: nil,
      attribute_type: :updated,
      include_version_name: true,
      id: nil,
      updated_by: nil,
      updated_at: nil,
      class_name: nil,
      version_name: nil,
      updated_by_user: nil,
      locale: nil,
      can_remove_version_name: nil,
      icon: nil,
      icon_only: nil,
      is_active: false,
      watch_list_id: nil,
      active_id: nil,
      diff_id: nil,
      right_side: false,
      diff_view: false
    }.freeze

    HistoryListEntry = Struct.new(*HISTORY_LIST_ARGUMENTS.keys, keyword_init: true) do
      def initialize(**args)
        args.reverse_merge!(HISTORY_LIST_ARGUMENTS)

        unless args[:item].nil?
          I18n.with_locale(args[:item].first_available_locale) do
            args[:id] ||= args[:item].id
            args[:updated_by] ||= args[:item].try("#{args[:attribute_type]}_by")
            args[:updated_at] ||= args[:item].try("#{args[:attribute_type]}_at")
            args[:class_name] ||= args[:item].class.name
            args[:version_name] ||= args[:include_version_name] ? args[:item].version_name : nil
            args[:updated_by_user] ||= args[:item].try("#{args[:attribute_type]}_by_user")
            args[:locale] ||= Array.wrap(args[:locales]).join(', ')
            args[:can_remove_version_name] ||= DataCycleCore::Feature::NamedVersion.enabled? && args[:user].can?(:remove_version_name, args[:item])
          end
        end

        super(**args)
      end

      def path_id
        right_side ? id : diff_id
      end

      def path_history_id
        right_side ? diff_id : id
      end

      def history_thing_path_params(content)
        { id: path_id || content.id, history_id: path_history_id, watch_list_id: watch_list_id }
      end

      def active?
        [active_id, diff_id].compact.include?(id)
      end

      def active_class
        return 'active' if active_id == id
        return 'diff-active' if diff_id == id
      end

      def source_icon?
        diff_view && active? && (right_side ? diff_id == id : active_id == id)
      end

      def target_icon?
        diff_view && active? && (right_side ? active_id == id : diff_id == id)
      end

      def icon
        if source_icon?
          { class: 'fa fa-long-arrow-left', tooltip: 'history.active_source' }
        elsif target_icon?
          { class: 'fa fa-long-arrow-right', tooltip: 'history.active_target' }
        elsif diff_view && !icon_only
          self[:icon] = right_side ? { class: 'fa fa-long-arrow-right', tooltip: 'history.use_as_target' } : { class: 'fa fa-long-arrow-left', tooltip: 'history.use_as_source' }
        else
          self[:icon]
        end
      end
    end
  end
end
