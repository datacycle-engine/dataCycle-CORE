# frozen_string_literal: true

# Root crumb
crumb :root do
  link to_html_string("<i class='fa fa-folder-open-o' aria-hidden='true'></i>#{DataCycleCore.breadcrumb_root_name}"), root_path, authorized: can?(:index, :backend)
end

# Settings
crumb :settings do
  link to_html_string(t('data_cycle_core.settings', locale: DataCycleCore.ui_language)), settings_path, authorized: can?(:settings, :backend)
end

# Administration
crumb :admin do
  link to_html_string(t('data_cycle_core.administration', locale: DataCycleCore.ui_language)), admin_path, authorized: can?(:manage, :dash_board)
end

crumb :classifications do
  link to_html_string(t('data_cycle_core.classifications', locale: DataCycleCore.ui_language)), classifications_path, authorized: can?(:manage, DataCycleCore::Classification)
  parent :admin if can?(:manage, :dash_board)
end

crumb :classification_tree_label do |label|
  link to_html_string(t("tree_view.#{label.name}")), nil, authorized: can?(:manage, DataCycleCore::Classification)
  parent :admin if can?(:manage, :dash_board)
end

# Default Index Crumb
crumb :index do |type_name|
  link to_html_string("DataCycleCore::#{type_name.classify}".constantize.model_name.human(count: 2, locale: DataCycleCore.ui_language)), url_for(action: :index, controller: type_name), authorized: can?(:index, "DataCycleCore::#{type_name.classify}".constantize)
end

# Default Show Crumb
crumb :show do |item, title_method, watch_list|
  link to_html_string(item.model_name.human(locale: DataCycleCore.ui_language), item.try(title_method)), polymorphic_path(item), authorized: can?(:show, item)
  parent :show, watch_list, :name if watch_list.present?
end

# Default Edit Crumbs
crumb :edit do |item, title_method, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.edit', locale: DataCycleCore.ui_language).capitalize}"), edit_polymorphic_path(item), authorized: can?(:edit, item)
  parent :show, item, title_method, watch_list
end

crumb :edit_from_index do |item, title_method|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.edit', locale: DataCycleCore.ui_language).capitalize}", item.try(title_method)), edit_polymorphic_path(item), authorized: can?(:edit, item)
  parent :index, item.class.table_name
end

# Content Crumbs
crumb :content do |content, watch_list|
  I18n.with_locale(content.first_available_locale) do
    link to_html_string(t("content_type.#{content.template_name.downcase}", default: content.template_name.titleize, locale: DataCycleCore.ui_language), content.title), polymorphic_path(content, watch_list_id: watch_list), authorized: can?(:show, content)
  end

  if watch_list
    if content.try(:parent).present? && content.parent.try(:watch_lists)&.include?(watch_list)
      parent :content, content.parent, watch_list
    else
      parent :show, watch_list, :name
    end
  elsif content.try(:parent)
    parent :content, content.parent, watch_list
  else
    parent :root
  end
end

crumb :edit_content do |item, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.edit', locale: DataCycleCore.ui_language).capitalize}"), edit_polymorphic_path(item), authorized: can?(:edit, item)
  parent :content, item, watch_list
end

# History Crumbs
crumb :show_history do |item, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-history'></i>#{t('actions.show', locale: DataCycleCore.ui_language).capitalize}"), polymorphic_path(item), authorized: can?(:history, item)
  parent :content, item, watch_list
end

crumb :show_compare do |item, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-columns'></i>#{t('common.compare', locale: DataCycleCore.ui_language).capitalize}"), polymorphic_path(item), authorized: can?(:show, item)
  parent :content, item, watch_list
end

# Publicationcalendar Crumb
crumb :'data_cycle_core/publications' do
  link to_html_string("<i class='fa fa-calendar' aria-hidden='true'></i>#{t('data_cycle_core.publications_calendar', locale: DataCycleCore.ui_language)}"), publications_path, authorized: can?(:index, :publication)
end

# Stored Filters Crumb
crumb :'data_cycle_core/stored_filters' do
  link to_html_string("<i aria-hidden='true' class='fa fa-search'></i> #{t('data_cycle_core.stored_searches.my_searches', locale: DataCycleCore.ui_language)}"), stored_filters_path, authorized: can?(:index, DataCycleCore::StoredFilter)
end

# Documentation
crumb :documentation do
  link t('data_cycle_core.documentation.root', locale: DataCycleCore.ui_language), '#', authorized: false

  path_segments = params['path'].split('/')
  (0..path_segments.length - 1).each do |i|
    translation_key = (['data_cycle_core', 'documentation'] + path_segments[0..i]).join('.')

    if t(translation_key, locale: DataCycleCore.ui_language).is_a? Hash
      translation_key += '.root'
    end

    link t(translation_key, locale: DataCycleCore.ui_language), '/' + (['docs'] + path_segments[0..i]).join('/'), authorized: true
  end
end

# Schema
crumb :schema do
  link t('data_cycle_core.schema.root', locale: DataCycleCore.ui_language), '#', authorized: false
end
