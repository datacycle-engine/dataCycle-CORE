# frozen_string_literal: true

configs = Dir[Rails.root.join('config', 'configurations', Rails.env, '*.yml')]
configs.concat(Dir[Rails.root.join('config', 'configurations', '*.yml')])
configs.concat(Dir[DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*.yml')])
configs.concat(Dir[DataCycleCore::Engine.root.join('config', 'configurations', '*.yml')])

configs.each do |file_name|
  next unless DataCycleCore.respond_to?(File.basename(file_name, '.*'))

  DataCycleCore.send(File.basename(file_name, '.*') + '=', DataCycleCore.try(File.basename(file_name, '.*'))&.deep_merge(YAML.safe_load(ERB.new(File.read(file_name)).result, [Symbol])) { |_k, v1, _v2| v1 }&.with_indifferent_access).freeze
end
