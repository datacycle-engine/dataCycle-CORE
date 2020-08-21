# frozen_string_literal: true

namespace :dc do
  namespace :check do
    desc 'check templates to move to new template_sets'
    task only_basic: :environment do
      removed_templates = [
        'Angebot', 'Biografie', 'Datei', 'Interview', 'Linktipps', 'Quiz',
        'Frage', 'Antwort', 'Rezept', 'SocialMediaPosting', 'Textblock', 'Website', 'Zitat',
        'Zeitleiste', 'Zeitleisten-Eintrag'
      ]

      deleteable = []
      used = []
      history_used = []
      removed_templates.each do |template_name|
        items = DataCycleCore::Thing.where(template_name: template_name).count
        if items < 2
          deleteable.push(template_name)
        else
          used.push({ template_name => items })
        end

        history_items = DataCycleCore::Thing::History.where(template_name: template_name).count
        history_used.push({ template_name => history_items }) if history_items.positive?
      end

      puts 'templates can be deleted:'
      ap deleteable

      puts "\nthe following templates contain data but will be removed:"
      ap used
      puts "\nafter update the following history items contain obsolete templates:"
      ap history_used

      puts "\n\ncheck the follwing templates:"
    end

    desc 'check for invalid overlay properties'
    task invalid_overlay_definitions: :environment do
      puts "### Check for invalid overlay data_definition\r"
      count = 0
      DataCycleCore::Thing.where(template: true).to_a.select { |thing| thing.overlay_template_name.present? }.each do |thing|
        next if thing.add_overlay_property_names.blank?
        count += 1
        found_things = DataCycleCore::Thing.where(template: false, template_name: thing.overlay_template_name).count
        puts "#{('# ' + thing.template_name).ljust(41)} | #{thing.overlay_template_name}| #{found_things} | #{thing.add_overlay_property_names.join(',')} \r"
      end
      puts "no invalid data found\r" if count.zero?
    end
  end
end
