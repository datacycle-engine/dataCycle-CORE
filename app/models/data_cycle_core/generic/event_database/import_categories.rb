module DataCycleCore::Generic::EventDatabase::ImportCategories
  def import_data(**options)
    import_classifications(@source_type,
                           options.try(:[], :import).try(:[], :tree_label) || 'Veranstaltungsdatenbank - ',
                           method(:load_root_classifications).to_proc,
                           method(:load_child_classifications).to_proc,
                           method(:load_parent_classification_alias).to_proc,
                           method(:extract_data).to_proc,
                           **options)
  end

  protected

  def load_root_classifications(mongo_item, locale)
    mongo_item.where("dump.#{locale}.parentId": nil)
  end

  def load_child_classifications(mongo_item, parent_category_data, locale)
    mongo_item.where("dump.#{locale}.parentId": parent_category_data['id'])
  end

  def load_parent_classification_alias(raw_data)
    DataCycleCore::Classification
      .find_by(external_source_id: external_source.id, external_key: "CATEGORY:#{raw_data['parentId']}")
      .try(:primary_classification_alias)
  end

  def extract_data(raw_data)
    {
      external_id: "CATEGORY:#{raw_data['id']}",
      name: raw_data['name']
    }
  end
end