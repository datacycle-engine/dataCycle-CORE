# frozen_string_literal: true

default_options = {
  header_type: :full,
  classifications: true
}

options = default_options.merge(defined?(options) ? options || {} : {})

unless options[:header_type] == :overlay
  json.content_partial! 'context', content: content

  json.set! '@id', send("api_v2_#{content.class.class_name.tableize.singularize}_url", content)
  json.set! 'identifier', content.id

end

if options[:header_type] == :full
  json.set! 'dateCreated', content.created_at
  json.set! 'dateModified', content.updated_at

  json.set! 'datePublished', l(content.validity_period.valid_from.to_date, locale: :en) unless content.try(:validity_period).try(:valid_from).nil?
  json.set! 'expires', l(content.validity_period.valid_until.to_date, locale: :en) unless content.try(:validity_period).try(:valid_until).nil?

  json.set! 'url', send("#{content.class.class_name.tableize.singularize}_url", content)

  internal_classifications = DataCycleCore.internal_classification_attributes.map { |internal_classification|
    content.send(internal_classification)&.includes(:classification_aliases)&.map(&:classification_aliases)&.flatten&.uniq if content.respond_to?(internal_classification)
  }.compact.flatten
  json.partial! 'classifications', classification_aliases: internal_classifications, key: 'classifications'

end
