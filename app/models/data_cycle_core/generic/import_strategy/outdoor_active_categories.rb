module DataCycleCore::Generic::ImportStrategy::OutdoorActiveCategories
  def import_data(**options)
    #import_classifications(
    # type,
    # tree_name,
    # load_root_classifications,
    # load_child_classifications,
    # load_parent_classification_alias,
    # extract_data,
    # **options)
    import_classifications(
      @source_type,
      "#{options.try(:[], :import).try(:[], :tree_label) || 'OutdoorActive'} - Kategorien",
      self.method(:load_root_classifications).to_proc,
      self.method(:load_child_classifications).to_proc,
      self.method(:load_parent_classification_alias).to_proc,
      self.method(:extract_data).to_proc,
      **options
    )
  end

  protected

  def load_root_classifications(locale)
    @source_type.where("dump.#{locale}.parentId": nil)
  end

  def load_child_classifications(parent_category_data, locale)
    @source_type.where("dump.#{locale}.parentId": parent_category_data['id'])
  end

  def load_parent_classification_alias(raw_data)
    DataCycleCore::Classification
      .find_by(external_source_id: external_source.id, external_key: raw_data['parentId'])
      .try(:primary_classification_alias)
  end

  def extract_data(raw_data)
    {
      external_id: raw_data['id'],
      name: raw_data['name']
    }
  end

end
