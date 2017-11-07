module DataCycleCore::Generic::Feratel::ImportDataOwners
  def import_data(**options)
    import_classifications(
      @source_type,
      options.try(:[], :import).try(:[], :tree_label) || 'Feratel - Inhaber',
      method(:load_root_classifications).to_proc,
      ->(_, _, _) { [] },
      ->(_) { nil },
      method(:extract_data).to_proc,
      **options
    )
  end

  protected

  def load_root_classifications(mongo_item, locale)
    mongo_item.collection.aggregate(mongo_item.where(:_id.ne => nil)
      .project(
        "dump.#{locale}.Id": "$dump.#{locale}.Details.DataOwner.text",
        "dump.#{locale}.Name": "$dump.#{locale}.Details.DataOwner.text"
      ).group(
        _id: "$dump.#{locale}.Id",
        :dump.first => '$dump'
      ).pipeline
    )
  end

  def extract_data(raw_data)
    {
      external_id: "OWNER:#{Digest::MD5.hexdigest(raw_data['Id'])}",
      name: raw_data['Name']
    }
  end
end
