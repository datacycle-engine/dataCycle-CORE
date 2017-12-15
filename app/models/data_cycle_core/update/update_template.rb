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
    I18n.with_locale(content_item.available_locales.first) do
      content_item.save(touch: false)
    end
  end

  def write(_, _, _)
    {}
  end

end
