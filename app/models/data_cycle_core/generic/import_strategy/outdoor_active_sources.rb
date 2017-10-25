module DataCycleCore::Generic::ImportStrategy::OutdoorActiveSources
  def import_data(**options)
    @source_target = options.try(:[], :import).try(:[], :source_target).constantize

    import_classifications(
      @source_type,
      "#{options.try(:[], :import).try(:[], :tree_label) || 'OutdoorActive'} - Quellen",
      self.method(:load_root_classifications).to_proc,
      ->(_, _) { [] },
      ->(_) { nil },
      self.method(:extract_data).to_proc,
      **options
    )
  end

  protected

  def load_root_classifications(locale)
    @source_target.collection.aggregate(@source_target.where(:_id.ne => nil)
      .project(
        "dump.#{locale}.id": "$dump.#{locale}.meta.source.id",
        "dump.#{locale}.name": "$dump.#{locale}.meta.source.name"
      ).group(
        _id: "$dump.#{locale}.id",
        :dump.first => "$dump"
      ).pipeline
    )
  end

  def extract_data(raw_data)
    {
      external_id: raw_data['id'],
      name: raw_data['name']
    }
  end

end
