# frozen_string_literal: true

configs = Dir[DataCycleCore::Engine.root.join('config', 'configurations', '*.yml')]
configs.concat(Dir[DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*.yml')])
configs.concat(Dir[Rails.root.join('config', 'configurations', '*.yml')])
configs.concat(Dir[Rails.root.join('config', 'configurations', Rails.env, '*.yml')])

configs.each do |file_name|
  DataCycleCore.try(File.basename(file_name, '.*'))&.deep_merge!(YAML.safe_load(File.open(file_name)))
end
