# frozen_string_literal: true

# Root crumb
crumb :root do |stored_filter|
  link to_html_string("<i class='fa fa-folder-open-o' aria-hidden='true'></i> #{DataCycleCore.breadcrumb_root_name}"), root_path, authorized: can?(:index, :backend)

  link stored_filter.name, '#', authorized: false if stored_filter.present? && stored_filter.name.present?
end

crumb :exception do |type|
  link to_html_string(exception_title(type)), polymorphic_path("#{type}_exception"), authorized: true
end

# Settings
crumb :settings do
  link to_html_string(t('data_cycle_core.settings', locale: active_ui_locale)), settings_path, authorized: can?(:settings, :backend)
end

# Administration
crumb :admin do
  link to_html_string(t('data_cycle_core.administration', locale: active_ui_locale)), admin_path, authorized: can?(:manage, :dash_board)
end

# Administration
crumb :reports do
  link to_html_string(t('data_cycle_core.reports.root', locale: active_ui_locale)), reports_path, authorized: can?(:manage, :reports)
end

crumb :classifications do
  link to_html_string(t('data_cycle_core.classifications', locale: active_ui_locale)), classifications_path, authorized: can?(:manage, DataCycleCore::Classification)
  parent :admin if can?(:manage, :dash_board)
end

crumb :classification_tree_label do |label|
  link to_html_string(t("tree_view.#{label.name}", default: label.name, locale: active_ui_locale)), nil, authorized: can?(:manage, DataCycleCore::Classification)
  parent :admin if can?(:manage, :dash_board)
end

# Default Index Crumb
crumb :index do |type_name|
  link to_html_string("DataCycleCore::#{type_name.classify}".constantize.model_name.human(count: 2, locale: active_ui_locale)), url_for(action: :index, controller: type_name), authorized: can?(:index, "DataCycleCore::#{type_name.classify}".constantize)
end

# Default Show Crumb
crumb :show do |item, title_method, watch_list|
  link to_html_string(item.model_name.human(locale: active_ui_locale), item.try(title_method)), polymorphic_path(item), authorized: can?(:show, item)
  parent :show, watch_list, :name if watch_list.present?
end

# Default Edit Crumbs
crumb :edit do |item, title_method, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.edit', locale: active_ui_locale).capitalize}"), edit_thing_path(item), authorized: can?(:edit, item)
  parent :show, item, title_method, watch_list
end

crumb :edit_from_index do |item, title_method|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.edit', locale: active_ui_locale).capitalize}", item.try(title_method)), edit_thing_path(item), authorized: can?(:edit, item)
  parent :index, item.class.table_name
end

crumb :bulk_edit do |item|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.bulk_edit', locale: active_ui_locale).capitalize}"), edit_thing_path(item), authorized: can?(:edit, item)
  parent :show, item, :name
end

# Content Crumbs
crumb :content do |content, watch_list|
  I18n.with_locale(content.first_available_locale) do
    link to_html_string(content.translated_template_name(active_ui_locale), content.title), thing_path(content, watch_list_id: watch_list), authorized: can?(:show, content)
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
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>#{t('actions.edit', locale: active_ui_locale).capitalize}"), edit_thing_path(item), authorized: can?(:edit, item)
  parent :content, item, watch_list
end

# Duplicate Merge Crumbs
crumb :merge_content do |item, duplicate, watch_list|
  link to_html_string("<i class='fa fa-code-fork' aria-hidden='true'></i>#{t('duplicate.merge_content', locale: active_ui_locale).capitalize}"), merge_with_duplicate_thing_path(id: item.id, duplicate_id: duplicate.id), authorized: can?(:merge_duplicates, item)
  parent :content, item, watch_list
end

# History Crumbs
crumb :show_history do |item, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-history'></i>#{t('actions.show', locale: active_ui_locale).capitalize}"), thing_path(item), authorized: can?(:history, item)
  parent :content, item, watch_list
end

crumb :show_compare do |item, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-columns'></i>#{t('common.compare', locale: active_ui_locale).capitalize}"), thing_path(item), authorized: can?(:show, item)
  parent :content, item, watch_list
end

# Publicationcalendar Crumb
crumb :'data_cycle_core/publications' do
  link to_html_string("<i class='fa fa-calendar' aria-hidden='true'></i>#{t('data_cycle_core.publications_calendar', locale: active_ui_locale)}"), publications_path, authorized: can?(:index, :publication)
end

# Stored Filters Crumb
crumb :'data_cycle_core/stored_filters' do
  link to_html_string("<i aria-hidden='true' class='fa fa-search'></i> #{t('data_cycle_core.stored_searches.my_searches', locale: active_ui_locale)}"), stored_filters_path, authorized: can?(:index, DataCycleCore::StoredFilter)
end

# Documentation
crumb :documentation do
  link t('data_cycle_core.documentation.root', locale: active_ui_locale), docs_path, authorized: true

  path_segments = (params['path'] || '').split('/')

  (0..path_segments.length - 1).each do |i|
    translation_key = (['data_cycle_core', 'documentation'] + path_segments[0..i]).join('.')

    translation_key += '.root' if t(translation_key, locale: active_ui_locale).is_a? Hash

    link t(translation_key, locale: active_ui_locale), docs_with_path_path(path_segments[0..i]), authorized: true
  end
end

crumb :acknowledgments do
  link 'Acknowledgments', acknowledgments_path, authorized: true
end

# Schema
crumb :schema do
  link t('data_cycle_core.schema.root', locale: active_ui_locale), schema_path, authorized: params[:id].present?

  link params[:id], '#', authorized: false if params[:id].present?
end
