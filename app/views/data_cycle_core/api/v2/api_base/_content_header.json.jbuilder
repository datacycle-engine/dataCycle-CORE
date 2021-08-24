# frozen_string_literal: true

default_options = {
  header_type: :full
}

options = default_options.merge(defined?(options) ? options || {} : {})

unless options[:header_type] == :overlay
  json.content_partial! 'context', content: content

  json.set! '@id', send("api_v2_#{content.class.class_name.tableize.singularize}_url", @api_subversion, content, @language != I18n.available_locales.first.to_s ? { language: @language } : {})
  json.set! 'identifier', content.id
  json.set! 'url', send("#{content.class.class_name.tableize.singularize}_url", content, @language != I18n.available_locales.first.to_s ? { locale: @language } : {})

end

if options[:header_type] == :full
  json.set! 'dateCreated', content.created_at
  json.set! 'dateModified', content.updated_at

  json.set! 'datePublished', content.validity_period.valid_from.to_date.iso8601 unless content.try(:validity_period).try(:valid_from).nil?
  json.set! 'expires', content.validity_period.valid_until.to_date.iso8601 unless content.try(:validity_period).try(:valid_until).nil?

  if @mode_parameters.include?('compact')
    classifications = content.classifications.includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
  elsif content.respond_to?('data_type')
    classifications = content.send('data_type')&.includes(:classification_aliases)&.map(&:classification_aliases)&.flatten&.uniq
  end

  json.partial! 'classifications', classification_aliases: classifications, key: 'classifications'
end
