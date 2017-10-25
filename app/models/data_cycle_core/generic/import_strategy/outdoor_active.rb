module DataCycleCore::Generic::ImportStrategy::OutdoorActive

  def import(**options, &block)
    callbacks = DataCycleCore::Callbacks.new(block)

    # # categories can only be imported for one single locale
    # import_categories(callbacks, **(options || {}).merge(locales: [I18n.default_locale]))
    # # regions can only be imported for one single locale
    # import_regions(callbacks, **(options || {}).merge(locales: [I18n.default_locale]))
    # # regions can only be imported for one single locale
    # import_sources(callbacks, **(options || {}).merge(locales: [I18n.default_locale]))

    import_pois(callbacks, **options)
  end

  def import_categories(callbacks = DataCycleCore::Callbacks.new, **options)
    #import_classifications(type, tree_name, load_root_classifications, load_child_classifications, load_parent_classification_alias, extract_data, **options)
    import_classifications(
      Category,
      "#{self.class.parent.to_s.demodulize} - Kategorien",
      ->(locale) { Category.where("dump.#{locale}.parentId": nil) },
      ->(parent_category_data, locale) { Category.where("dump.#{locale}.parentId": parent_category_data['id']) },
      ->(raw_data) {
        DataCycleCore::Classification
          .find_by(external_source_id: external_source.id, external_key: raw_data['parentId'])
          .try(:primary_classification_alias)
      },
      ->(raw_data) {
        {
          external_id: raw_data['id'],
          name: raw_data['name']
        }
      },
      callbacks,
      **options
    )
  end

  def import_regions(callbacks = DataCycleCore::Callbacks.new, **options)
    import_classifications(
      Region,
      "#{self.class.parent.to_s.demodulize} - Regionen",
      ->(locale) { Region.where("this.dump.#{locale}.id == this.dump.#{locale}.parentId") },
      ->(parent_category_data, locale) {
        Region.where(
          "dump.#{locale}.parentId": parent_category_data['id'],
          "dump.#{locale}.id": {'$ne': parent_category_data['id']}
        )
      },
      ->(raw_data) {
        return nil if raw_data['parentId'] == raw_data['id']

        DataCycleCore::Classification
          .find_by(external_source_id: external_source.id, external_key: raw_data['parentId'])
          .try(:primary_classification_alias)
      },
      ->(raw_data) {
        {
          external_id: raw_data['id'],
          name: raw_data['name']
        }
      },
      callbacks,
      **options
    )
  end

  def import_sources(callbacks = DataCycleCore::Callbacks.new, **options)
    import_classifications(
      Category,
      "#{self.class.parent.to_s.demodulize} - Quellen",
      ->(locale) {
        Poi.collection.aggregate(Poi.where(:_id.ne => nil)
          .project(
            "dump.#{locale}.id": "$dump.#{locale}.meta.source.id",
            "dump.#{locale}.name": "$dump.#{locale}.meta.source.name"
          ).group(
            _id: "$dump.#{locale}.id",
            :dump.first => "$dump"
          ).pipeline
        )
      },
      ->(_, _) { [] },
      ->(_) { nil },
      ->(raw_data) {
        {
          external_id: raw_data['id'],
          name: raw_data['name']
        }
      },
      callbacks,
      **options
    )
  end

  def import_pois(callbacks = DataCycleCore::Callbacks.new, **options)
    # import_contents(source_type, target_type, load_contents, process_content, callbacks, **options)
    import_contents(
      Poi,
      DataCycleCore::Place,
      ->(locale) { Poi.where("dump.#{locale}.frontendtype": 'poi') },
      ->(raw_data, template, locale) {
        I18n.with_locale(locale) do
          images = (raw_data.try(:[], 'images').try(:[], 'image') || []).map { |raw_image_data|
            create_or_update_content(
              CreativeWork,
              load_image_template(raw_image_data),
              extract_image_data(raw_image_data).with_indifferent_access
            )
          }

          categories = [raw_data.dig('category', 'id')].reject(&:blank?).map { |id|
            DataCycleCore::Classification.find_by(external_key: id)
          }.reject(&:nil?)

          regions = raw_data.dig('regions', 'region').map { |r| r['id'] }.reject(&:blank?).map { |id|
            DataCycleCore::Classification.find_by(external_key: id)
          }.reject(&:nil?)

          sources = [raw_data.dig('meta', 'source', 'id')].reject(&:blank?).map { |id|
            DataCycleCore::Classification.find_by(external_key: id)
          }

          create_or_update_content(
            Place,
            template,
            extract_poi_data(raw_data).with_indifferent_access.merge(
              image: images.map(&:id),
              categories: categories.map(&:id),
              regions: regions.map(&:id),
              source: sources.map(&:id).take(1)
            ).with_indifferent_access
          )
        end
      },
      callbacks,
      **options
    )
  end

  protected

  def extract_poi_data(raw_data)
    raw_data.extend(PoiAttributeTransformation).to_h
  end

  def extract_image_data(raw_data)
    raw_data.extend(ImageAttributeTransformation).to_h
  end

  def create_or_update_content(clazz, template, data)
    content = clazz.find_or_initialize_by(external_source_id: external_source.id,
                                          external_key: data['external_key'])
    content.metadata ||= {}
    content.metadata['validation'] = template.metadata['validation']

    content.set_data_hash(content.get_data_hash.merge(data))

    content.tap(&:save!)
  end

  def load_image_template(_)
    if self.class.to_s.deconstantize.constantize.content_template.nil?
      raise 'Missing configuration for image templates'
    elsif self.class.to_s.deconstantize.constantize.image_template.is_a? String
      begin
        DataCycleCore::CreativeWork.find_by!(template: true,
                                             headline: self.class.to_s.deconstantize.constantize.image_template)
      rescue ActiveRecord::RecordNotFound
        raise "Missing template #{self.class.to_s.deconstantize.constantize.image_template} for #{target_type}"
      end
    else
      raise NotImplementedError
    end
  end
end
