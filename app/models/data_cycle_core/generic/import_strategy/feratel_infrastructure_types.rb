module DataCycleCore::Generic::ImportStrategy::FeratelInfrastructureTypes
  def import_data(**options)
    import_classifications(@source_type,
                           options.try(:[], :import).try(:[], :tree_label) || 'Feratel - InfrastructureTypes',
                           method(:load_root_classifications).to_proc,
                           method(:load_child_classifications).to_proc,
                           method(:load_parent_classification_alias).to_proc,
                           method(:extract_data).to_proc,
                           **options)
  end

  protected

  def load_root_classifications(locale)
    DataCycleCore::Generic::SourceType::InfrastructureType.where("dump.#{locale}.Name.Translation.Language": 'de')
  end

  def load_child_classifications(parent_category_data, locale)
    if parent_category_data['Id']
      []
    else
      DataCycleCore::Generic::SourceType::InfrastructureTopic.where("dump.#{locale}.Type": parent_category_data['Type'])
    end
  end

  def load_parent_classification_alias(raw_data)
    if raw_data['Id']
      DataCycleCore::Classification
        .find_by(external_source_id: external_source.id, external_key: "INFRASTRUCTURE_TYPE:#{raw_data['Type']}")
        .try(:primary_classification_alias)
    else
      nil
    end
  end

  def extract_data(raw_data)
    {
      external_id: raw_data['Id'].blank? ? "INFRASTRUCTURE_TYPE:#{raw_data['Type']}" : raw_data['Id'],
      name: raw_data.dig('Name', 'Translation', 'text')
    }
  end
end
