type = object.metadata['validation']['name']

begin
  json.partial! "#{object.class.class_name.underscore}_#{type.underscore}", object: object, nested: defined?(nested) ? nested : false
rescue ActionView::MissingTemplate => e
  logger.info "Using standard template for #{object.class.to_s} - #{type}"

  json.partial! 'base', object: object, options: defined?(options) ? options : {}
end
