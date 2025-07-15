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
  end
end
