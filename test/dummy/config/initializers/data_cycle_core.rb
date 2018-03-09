DataCycleCore.setup do |config|
  config.access_tokens = [
    'd48a84faseei512hjkl159ggg9a72adf'
  ]

  config.template_path = Rails.root.join('..', '..', 'config', 'data_definitions', 'basic')
  config.default_template_paths = [
    # Rails.root.join('..', '..', 'config', 'data_definitions', 'basic')
    # Rails.root.join('..', '.', 'config', 'data_definitions', 'enhanced')
  ]
end
