module DataCycleCore::Generic::OutdoorActive::ImportFrontendTypes
  def import_data(**options)
    import_classifications(
      @source_type,
      "#{options.try(:[], :import).try(:[], :tree_label) || 'OutdoorActive'} - FrontendTypes",
      self.method(:load_root_classifications).to_proc,
      ->(_, _, _) { [] },
      ->(_) { nil },
      self.method(:extract_data).to_proc,
      **options
    )
  end

  protected

  def load_root_classifications(mongo_item, locale)
    mongo_item.collection.aggregate(mongo_item.where(:_id.ne => nil)
      .project(
        "dump.#{locale}.id": "$dump.#{locale}.frontendtype",
        "dump.#{locale}.frontendtype": "$dump.#{locale}.frontendtype"
      ).group(
        _id: "$dump.#{locale}.id",
        :dump.first => "$dump"
      ).pipeline
    )
  end

  def extract_data(raw_data)
    {
      external_id: "FRONTENDTYPE:#{Digest::MD5.new.update(raw_data['frontendtype']).hexdigest}",
      name: raw_data['frontendtype']
    }
  end

end
