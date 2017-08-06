type = object.metadata['validation']['name']

begin
  json.partial! "#{object.class.class_name.underscore}_#{type.underscore}", object: object, nested: defined?(nested) ? nested : false
rescue ActionView::MissingTemplate => e
  logger.info "Using standard template for #{object.class.to_s} - #{type}"

  json.partial! 'base', object: object, options: defined?(options) ? options : {}

  special_attributes = DataCycleCore.special_data_attributes +  DataCycleCore::ContentDecorator.special_property_names

  parts = DataCycleCore::CreativeWork.where(id: (DataCycleCore::ContentDecorator.new(object).embedded_object_names - special_attributes)
      .map { |k| object.metadata[k + '_hasPart'] }
      .flatten
    )

  if (parts.size > 0)
    json.hasPart(parts) do |part|
      json.partial! 'creative_work', object: part, options: { header_type: :none }
    end
  end
end
