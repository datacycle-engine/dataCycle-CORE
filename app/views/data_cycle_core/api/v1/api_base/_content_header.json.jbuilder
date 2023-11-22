# frozen_string_literal: true

default_options = {
  header_type: :full,
  classifications: true
}

options = default_options.merge(defined?(options) ? options || {} : {})

json.content_partial!('context', content:)

json.set! '@id', content.id
json.set! 'identifier', send("#{content.model_name.element.tableize.singularize}_url", content)

if options[:header_type] == :full
  json.set! 'dateCreated', content.created_at
  json.set! 'dateModified', content.updated_at

  json.set! 'datePublished', content.validity_period.valid_from.to_date.iso8601 unless content.try(:validity_period).try(:valid_from).nil?
  json.set! 'expires', content.validity_period.valid_until.to_date.iso8601 unless content.try(:validity_period).try(:valid_until).nil?

  json.set! 'url', send("#{content.model_name.element.tableize.singularize}_url", content)

  json.partial! 'classifications', classification_aliases: content.classifications.includes(:classification_aliases).map(&:classification_aliases).flatten.uniq
end
