# frozen_string_literal: true

namespace :dc do
  namespace :features do
    desc 'validate template definitions'
    task validate: :environment do
      puts "validating enabled features\n"

      missing_features = []

      DataCycleCore.features.each do |key, value|
        next if value['only_config']
        next unless value['enabled']

        feature = DataCycleCore::Feature[key]
        missing_features << key unless feature
      end

      if missing_features.any?
        puts(AmazingPrint::Colors.red("[✘] ... missing enabled features: #{missing_features.join(', ')}"))
        exit(-1)
      else
        puts(AmazingPrint::Colors.green('[✔] ... looks good 🚀'))
      end
    end

    # DataCycleCore::Feature::LocaleInheritance only reacts to saves, so contents that already
    # existed when it was enabled -- or whose reference gained its locales before that -- keep the
    # locales they had. Run this once after enabling it.
    desc 'create the inherited translations missing on contents opting into locale_inheritance'
    task inherit_locales: :environment do
      unless DataCycleCore::Feature::LocaleInheritance.enabled?
        puts(AmazingPrint::Colors.red('[✘] ... locale_inheritance is not enabled'))
        exit(-1)
      end

      template_names = DataCycleCore::Feature::LocaleInheritance.inheriting_properties.keys
      things = DataCycleCore::Thing.where(template_name: template_names).without_embedded

      puts "Processing #{things.count} contents (#{template_names.join(', ')})"

      things.find_each do |thing|
        locales_before = thing.translated_locales
        thing.inherit_missing_locales

        print(thing.reload.translated_locales == locales_before ? '~' : '.')
      end

      puts "\nProcessed contents"
    end
  end
end
