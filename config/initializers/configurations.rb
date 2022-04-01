# frozen_string_literal: true

configs = Dir[Rails.root.join('config', 'configurations', Rails.env, '*.yml')]
configs.concat(Dir[Rails.root.join('config', 'configurations', '*.yml')])
configs.concat(Dir[DataCycleCore::Engine.root.join('config', 'configurations', Rails.env, '*.yml')])
configs.concat(Dir[DataCycleCore::Engine.root.join('config', 'configurations', '*.yml')])

configs.each do |file_name|
  config_name = File.basename(file_name, '.*')

  next unless DataCycleCore.respond_to?(config_name)

  new_value = YAML.safe_load(ERB.new(File.read(file_name)).result, [Symbol])
  value = DataCycleCore.try(config_name)

  next unless new_value.present? || new_value.is_a?(FalseClass)

  new_value = value.deep_merge(new_value) { |_k, v1, _v2| v1 }.with_indifferent_access if value.is_a?(::Hash) && new_value.is_a?(::Hash)

  DataCycleCore.send("#{config_name}=", new_value).freeze
end
