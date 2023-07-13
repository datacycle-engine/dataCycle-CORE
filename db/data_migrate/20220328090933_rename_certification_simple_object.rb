# frozen_string_literal: true

class RenameCertificationSimpleObject < ActiveRecord::Migration[5.2]
  # uncomment the following line to disable transactions
  # disable_ddl_transaction!

  def up
    # Zertifizierung: short_report [...] -> short_reports [...]
    DataCycleCore::Thing.where(template: false, template_name: ['Zertifizierung']).each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('short_report')
          thing.content['short_reports'] = thing.content['short_report']
          thing.content = thing.content.except('short_report')
          thing.save!
        end
      end
    end
  end

  def down
    # Zertifizierung: short_report [...] -> short_reports [...]
    DataCycleCore::Thing.where(template: false, template_name: ['Zertifizierung']).each do |thing|
      thing.available_locales.each do |locale|
        I18n.with_locale(locale) do
          next unless thing.content&.key?('short_reports')
          thing.content['short_report'] = thing.content['short_reports']
          thing.content = thing.content.except('short_reports')
          thing.save!
        end
      end
    end
  end
end
