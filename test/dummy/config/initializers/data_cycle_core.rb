# frozen_string_literal: true

DataCycleCore.setup do |config|
  # general settings
  I18n.available_locales = [:de, :en]

  # only required for DataCycleCore dummy app
  Rails.application.config.assets.precompile += ['logo.svg', 'logo.png', 'location.svg']
  # Configure sensitive parameters which will be filtered from the log file.
  Rails.application.config.filter_parameters += [:password]
  # Require `belongs_to` associations by default. Previous versions had false.
  Rails.application.config.active_record.belongs_to_required_by_default = true
  Rails.application.config.session_store :cookie_store, key: '_dummy_session'

  config.template_path = Rails.root.join('config', 'data_definitions').freeze

  config.external_sources_path = Rails.root.join('..', '..', 'config', 'external_sources').freeze

  config.default_template_paths = [
    Rails.root.join('..', '..', 'config', 'data_definitions', 'basic'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'enhanced'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'media_archive'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'container'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_media'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'external_source_bergfex')
  ].freeze

  config.features = config.features.deep_merge(
    {
      publication_schedule: {
        enabled: true,
        classification_keys: ['output_channel']
      },
      overlay: {
        enabled: true
      }
    }
  )

  if ENV['RAILS_ENV'] == 'test'
    config.features = config.features.deep_merge(
      releasable: {
        enabled: true
      },
      container: {
        enabled: false,
        excluded: ['Bild', 'Video']
      },
      life_cycle: {
        enabled: true,
        attribute_keys: ['data_pool'],
        tree_label: 'Inhaltspools',
        ordered: ['Vorschläge', 'Recherche', 'Aktuelle Inhalte', 'Archiv']
      },
      idea_collection: {
        enabled: true,
        dependencies: ['life_cycle', 'container'],
        template: 'Recherche',
        life_cycle_stage: 'Recherche'
      }
    )
  end
end
