module DataCycleCore::Update::UpdateTemplate

  def query()
   @type.where(template: false).
      where(json_path(@type.arel_table[:metadata], quoted('{  validation, name }')).eq(quoted(@template.headline)))
  end

  def read(_)
    {}
  end

  def modify_content(content_item)
    content_item.metadata['validation'] = @template.metadata['validation']
    content_item.save
  end

  def write(_, _, _)
    {}
  end

end
