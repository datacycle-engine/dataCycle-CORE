# frozen_string_literal: true

class MigrateBergfexEntities < ActiveRecord::Migration[5.2]
  def up
    bergfex = DataCycleCore::ExternalSystem.find_by(name: 'Bergfex')
    return if bergfex.blank?
    bergfex.imported_things.where(template_name: 'See').each do |item|
      item.external_key = see_prefix + item.external_key
      item.save!
    end
    bergfex.imported_things.where(template_name: 'Skigebiet').each do |item|
      item.external_key = skigebiet_prefix + item.external_key
      item.save!
    end
  end

  def down
    bergfex = DataCycleCore::ExternalSystem.find_by(name: 'Bergfex')
    return if bergfex.blank?
    bergfex.imported_things.where(template_name: 'See').each do |item|
      next unless item.external_key.match(see_prefix)
      item.external_key = item.external_key[see_prefix.size..-1]
      item.save!
    end
    bergfex.imported_things.where(template_name: 'Skigebiet').each do |item|
      next unless item.external_key.match(skigebiet_prefix)
      item.external_key = item.external_key[skigebiet_prefix.size..-1]
      item.save!
    end
  end

  def see_prefix
    'Bergfex - See - '
  end

  def skigebiet_prefix
    'Bergfex - Skigebiet - '
  end
end
