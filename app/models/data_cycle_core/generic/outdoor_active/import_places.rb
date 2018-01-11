module DataCycleCore::Generic::OutdoorActive::ImportPlaces
  def import_data(**options)
    @image_template = options[:import][:image_template] || 'Bild'

    @poi_transformation = DataCycleCore::Generic::Transformations::Transformations.outdoor_active_to_place
    @poi_image_transformation = DataCycleCore::Generic::Transformations::Transformations.outdoor_active_to_image

    import_contents(@source_type, @target_type, self.method(:load_contents).to_proc, self.method(:process_content).to_proc, **options)
  end

  protected

  def load_contents(mongo_item, locale)
    mongo_item.all # frontendtype: ["poi", "hut", "lodging", "skiresort", "offerer"]
  end

  def process_content(raw_data, template, locale)
    I18n.with_locale(locale) do
      images = (raw_data.try(:[], 'images').try(:[], 'image') || []).map { |raw_image_data|
        create_or_update_content(
          DataCycleCore::CreativeWork,
          load_template(DataCycleCore::CreativeWork, @image_template),
          extract_image_data(raw_image_data).with_indifferent_access
        )
      }

      categories = [raw_data.dig('category', 'id')].reject(&:blank?).map { |id|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "CATEGORY:#{id}")
      }.reject(&:nil?)

      regions = (raw_data.dig('regions', 'region') || []).map { |r| r['id'] }.reject(&:blank?).map { |id|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "REGION:#{id}")
      }.reject(&:nil?)

      sources = [raw_data.dig('meta', 'source', 'id')].reject(&:blank?).map { |id|
        DataCycleCore::Classification.find_by(external_source_id: external_source.id, external_key: "SOURCE:#{id}")
      }
      sources_hash = sources.compact.blank? ? [] : sources.map(&:id).take(1)

      frontendtype = DataCycleCore::Classification.find_by(
          external_source_id: external_source.id,
          external_key: "FRONTENDTYPE:#{Digest::MD5.new.update(raw_data['frontendtype']).hexdigest}"
        ).try(:id)
      frontendtype = frontendtype.blank? ? [] : [frontendtype]

      create_or_update_content(
        @target_type,
        load_template(@target_type, @data_template),
        extract_poi_data(raw_data).merge(
          data_type: nil,
          image: images.map(&:id),
          categories: categories.map(&:id),
          regions: regions.map(&:id),
          source: sources_hash,
          frontend_type: frontendtype
        ).with_indifferent_access
      )
    end
  end

  def extract_image_data(raw_data)
    raw_data.nil? ? {} : @poi_image_transformation.call(raw_data)
  end

  def extract_poi_data(raw_data)
    raw_data.nil? ? {} : @poi_transformation.call(raw_data)
  end
end
