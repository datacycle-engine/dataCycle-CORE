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
        items = DataCycleCore::Thing.where(template_name:).count
        if items < 2
          deleteable.push(template_name)
        else
          used.push({ template_name => items })
        end

        history_items = DataCycleCore::Thing::History.where(template_name:).count
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
  end
end
