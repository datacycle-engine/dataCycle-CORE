# frozen_string_literal: true

class RenameSimpleObjectKeys < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    # url -> sulu_url (main_object) for POI, Unterkunft
    key_old = 'url'
    key_new = 'sulu_url'
    execute <<-SQL.squish
      UPDATE things
      SET metadata = (metadata - '#{key_old}') || jsonb_build_object('#{key_new}', metadata #> '{"#{key_old}"}' )
      WHERE metadata #> '{"#{key_old}"}' IS NOT NULL
      AND template_name IN ('POI', 'Unterkunft')
    SQL

    # potentialAction: [name, url] --> potential_action: [action_name, action_url]
    DataCycleCore::Thing.where(template_name: ['Angebot', 'Pauschalangebot']).find_each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('potentialAction')
          thing.content['potential_action'] = {
            'action_name' => thing.content.dig('potentialAction', 'name'),
            'action_url' => thing.content.dig('potentialAction', 'url')
          }
          thing.content = thing.content.except('potentialAction')
          thing.save!
        end
      end
    end

    # potential_action: [name, url] --> potential_action: [action_name, action_url]
    DataCycleCore::Thing.where(template_name: ['JobPosting']).find_each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('potential_action')
          thing.content['potential_action'] = {
            'action_name' => thing.content.dig('potential_action', 'name'),
            'action_url' => thing.content.dig('potential_action', 'url')
          }
          thing.save!
        end
      end
    end

    # url -> same_as (main_object) for Skigebiet, SnowResortOverlay, Skigebiet Bergfex
    DataCycleCore::Thing.where(template_name: ['Skigebiet', 'SnowResortOverlay', 'Skigebiet Bergfex']).find_each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('url')
          thing.content['same_as'] = thing.content['url']
          thing.content = thing.content.except('url')
          thing.save!
        end
      end
    end
  end

  def down
    # sulu_url -> url for POI, Unterkunft
    key_old = 'sulu_url'
    key_new = 'url'
    execute <<-SQL.squish
      UPDATE things
      SET metadata = (metadata - '#{key_old}') || jsonb_build_object('#{key_new}', metadata #> '{"#{key_old}"}' )
      WHERE metadata #> '{"#{key_old}"}' IS NOT NULL
      AND template_name IN ('POI', 'Unterkunft')
    SQL

    # potential_action: [action_name, action_url] --> potentialAction: [name, url]
    DataCycleCore::Thing.where(template_name: ['Angebot', 'Pauschalangebot']).find_each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('potential_action')
          thing.content['potentialAction'] = {
            'name' => thing.content.dig('potential_action', 'action_name'),
            'url' => thing.content.dig('potential_action', 'action_url')
          }
          thing.content = thing.content.except('potential_action')
          thing.save!
        end
      end
    end

    # potential_action: [action_name, action_url] --> potential_pction: [name, url]
    DataCycleCore::Thing.where(template_name: ['JobPosting']).find_each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('potential_action')
          thing.content['potential_action'] = {
            'name' => thing.content.dig('potential_action', 'action_name'),
            'url' => thing.content.dig('potential_action', 'action_url')
          }
          thing.save!
        end
      end
    end

    # same_as -> url (main_object) for Skigebiet, SnowResortOverlay, Skigebiet Bergfex
    DataCycleCore::Thing.where(template_name: ['Skigebiet', 'SnowResortOverlay', 'Skigebiet Bergfex']).find_each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('same_as')
          thing.content['url'] = thing.content['same_as']
          thing.content = thing.content.except('same_as')
          thing.save!
        end
      end
    end
  end
end
