module DataCycleCore::Generic::Feratel::ImportCategories
  def import_data(**options)
    import_classifications(@source_type,
                           options.try(:[], :import).try(:[], :tree_label) || 'Feratel - Kategorien',
                           method(:load_root_classifications).to_proc,
                           method(:load_child_classifications).to_proc,
                           method(:load_parent_classification_alias).to_proc,
                           method(:extract_data).to_proc,
                           **options)
  end

  protected

  def load_root_classifications(locale)
    @source_type.where("dump.#{locale}.Name.Translation.Language": 'de')
  end

  def load_child_classifications(_, _)
    []
  end

  def load_parent_classification_alias(_)
    nil
  end

  def extract_data(raw_data)
    {
      external_id: raw_data['Id'],
      name: raw_data.dig('Name', 'Translation', 'text')
    }
  end
end
