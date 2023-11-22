# frozen_string_literal: true

class MigrateVTicketEntities < ActiveRecord::Migration[5.2]
  def up
    vticket = DataCycleCore::ExternalSystem.find_by(name: 'V-Ticket')
    return if vticket.blank?
    vticket.imported_things.where(template_name: 'Event').find_each do |item|
      item.external_key = event_prefix + item.external_key
      item.save!
    end
    vticket.imported_things.where(template_name: 'Bild').find_each do |item|
      item.external_key = image_prefix + item.external_key
      item.save!
    end
    vticket.imported_things.where(template_name: 'Örtlichkeit').find_each do |item|
      item.external_key = location_prefix + item.external_key
      item.save!
    end
  end

  def down
    vticket = DataCycleCore::ExternalSystem.find_by(name: 'V-Ticket')
    return if vticket.blank?
    vticket.imported_things.where(template_name: 'Event').find_each do |item|
      next unless item.external_key.match(event_prefix)
      next if vticket.imported_things.where(external_key: item.external_key[event_prefix.size..-1].to_s).present?
      item.external_key = item.external_key[event_prefix.size..-1]
      item.save!
    end
    vticket.imported_things.where(template_name: 'Bild').find_each do |item|
      next unless item.external_key.match(image_prefix)
      next if vticket.imported_things.where(external_key: item.external_key[image_prefix.size..-1].to_s).present?
      item.external_key = item.external_key[image_prefix.size..-1]
      item.save!
    end
    vticket.imported_things.where(template_name: 'Örtlichkeit').find_each do |item|
      next unless item.external_key.match(location_prefix)
      next if vticket.imported_things.where(external_key: item.external_key[location_prefix.size..-1].to_s).present?
      item.external_key = item.external_key[location_prefix.size..-1]
      item.save!
    end
  end

  def event_prefix
    'V-Ticket Event: '
  end

  def image_prefix
    'V-Ticket Image: '
  end

  def location_prefix
    'V-Ticket Location: '
  end
end
