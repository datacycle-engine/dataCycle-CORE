# frozen_string_literal: true

if options[:disable_children].blank?
  related_objects = DataCycleCore::Thing
    .where(is_part_of: content.id)
    .includes({ concepts: [:concept_scheme], translations: [] })

  json.hasPart(related_objects) do |part|
    json.content_partial! 'details', content: part, options: options.merge({ disable_parent: true })
  end
end
