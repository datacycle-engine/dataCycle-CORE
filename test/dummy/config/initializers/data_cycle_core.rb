DataCycleCore.setup do |config|
  config.default_image_type = 'Bild'
  config.default_place_type = 'Ort'

  config.special_data_attributes = ['id', 'validity_period', 'creator']

  config.internal_data_attributes = ['creator', 'data_type', 'data_pool', 'is_part_of']

  config.ui_language = :de

  config.webhooks = {
    create: [],
    delete: [],
    update: []
  }

  config.excluded_filter_classifications = ['Angebotszeitraum', 'Website', 'Zitat', 'DataCycle - File', 'DataCycle - Image']

  config.allowed_content_api_classifications = ['Angebot', 'Artikel', 'Bild', 'Social', 'Media', 'Posting']

  config.access_tokens = [
    'd48a84faseei512hjkl159ggg9a72adf'
  ]
  config.release_codes = {
    partner: 1,
    review: 3
  }
end
