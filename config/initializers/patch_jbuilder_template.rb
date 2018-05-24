# frozen_string_literal: true

JbuilderTemplate.class_eval do
  def content_partial!(partial, parameters)
    partials = [
      "#{parameters[:content].class.class_name.underscore}_#{parameters[:content].template_name.underscore}_#{partial}",
      "#{parameters[:content].class.class_name.underscore}_#{partial}",
      "content_#{partial}"
    ]

    partials.each_with_index do |partial_file, idx|
      begin
        return partial!(partial_file, parameters)
      rescue ActionView::MissingTemplate => e
        raise e if idx == partials.size - 1
      end
    end
  end
end
