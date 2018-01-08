# Root crumb
crumb :root do
  link to_html_string("<i class='fa fa-folder-open-o' aria-hidden='true'></i>#{DataCycleCore.breadcrumb_root_name}"), root_path
end

crumb :admin do
  link to_html_string(t('data_cycle_core.administration', locale: DataCycleCore.ui_language)), '#'
end

crumb :classifications do
  link to_html_string(t('data_cycle_core.classifications', locale: DataCycleCore.ui_language)), '#'
  parent :admin
end

# User
crumb :'data_cycle_core/users' do
  link to_html_string(DataCycleCore::User.model_name.human(count: 2, locale: DataCycleCore.ui_language)), users_path
end

crumb :edit_user do |user|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>Bearbeiten", user.email), edit_user_path(user)
  parent :'data_cycle_core/users' if can? :crud, DataCycleCore::User
end

crumb :'data_cycle_core/user_groups' do
  link to_html_string(DataCycleCore::UserGroup.model_name.human(count: 2, locale: DataCycleCore.ui_language)), user_groups_path
end

crumb :edit_user_group do |user_group|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>Bearbeiten", user_group.name), edit_user_group_path(user_group)
  parent :'data_cycle_core/user_groups' if can? :crud, DataCycleCore::UserGroup
end

crumb :edit_resource do |resource, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-pencil'></i>Bearbeiten"), edit_polymorphic_path(resource)
  parent resource, watch_list
end

crumb :show_history do |resource, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-history'></i>Ansehen"), edit_polymorphic_path(resource)
  parent resource, watch_list
end

crumb :show_compare do |resource, watch_list|
  link to_html_string("<i aria-hidden='true' class='fa fa-columns'></i>Vergleichen"), edit_polymorphic_path(resource)
  parent resource, watch_list
end

# Creative Work
crumb :'data_cycle_core/creative_work' do |creative_work, watch_list|

  I18n.with_locale(creative_work.first_available_locale) do
    link to_html_string(creative_work.content_type, creative_work.title), polymorphic_path(creative_work, watch_list_id: watch_list)
  end

  if watch_list
    if creative_work.parent && creative_work.parent.watch_lists.include?(watch_list)
      parent creative_work.parent, watch_list
    else
      parent watch_list
    end
  elsif creative_work.parent
    parent creative_work.parent, watch_list
  else
    parent :root
  end
end

# Place
crumb :'data_cycle_core/places' do
  link to_html_string("Orte"), places_path
end

crumb :'data_cycle_core/place' do |place, watch_list|
  link to_html_string(place.metadata['validation']['name'], place.name), place_path(place, watch_list_id: watch_list)

  if watch_list
    parent watch_list
  end
  # parent :'data_cycle_core/places'
end

# Person
crumb :'data_cycle_core/persons' do
  link to_html_string("Personen"), persons_path
end

crumb :'data_cycle_core/person' do |person, watch_list|
  link to_html_string("Person", person.given_name + " " + person.family_name), person_path(person, watch_list_id: watch_list)

  if watch_list
    parent watch_list
  end
  # parent :'data_cycle_core/persons'
end

# Event
crumb :'data_cycle_core/events' do
  link to_html_string("Events"), events_path
end

crumb :'data_cycle_core/event' do |event, watch_list|
  link to_html_string("Event", event.headline), events_path(event, watch_list_id: watch_list)

  if watch_list
    parent watch_list
  end
  # parent :'data_cycle_core/persons'
end

# Merkliste
crumb :'data_cycle_core/watch_lists' do
  link to_html_string("Merklisten"), watch_lists_path
end

crumb :'data_cycle_core/watch_list' do |watch_list|
  link to_html_string("Merkliste", watch_list.headline), watch_list_path(watch_list)

  # parent :'data_cycle_core/watch_lists'
end
crumb :'data_cycle_core/subscriptions' do
  link to_html_string("Abos"), subscriptions_path
end
