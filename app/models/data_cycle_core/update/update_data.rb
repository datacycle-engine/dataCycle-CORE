module DataCycleCore::Update::UpdateData
  def query()
   @type.where(template: false).
      where(json_path(@type.arel_table[:metadata], quoted('{  validation, name }')).eq(quoted(@template.headline)))
  end

  def read(content_item)
    data_hash = content_item.get_data_hash
    data_hash = @transformation.call(data_hash) unless @transformation.nil?
    data_hash
  end

  def modify_content(content_item)
    content_item.metadata['validation'] = @template.metadata['validation']
    content_item.save
  end

  def write(content_item, data_hash, timestamp)
    content_item.set_data_hash(data_hash: data_hash, save_time: timestamp, prevent_history: true)
  end
end
