# frozen_string_literal: true

class ContentHelper
  # What a back-fill runs over: the contents to write, and the templates to walk to find which of
  # them declare the attribute at all.
  BackfillScope = Data.define(:things, :thing_templates)

  class << self
    # The scope a +dc:update_data+ back-fill runs over, shared by +computed_attributes+ and
    # +add_defaults+. It lives here rather than in the tasks because they fork per batch of 1000 and
    # cannot be exercised in a test process, while what they fork over decides how much work - and,
    # for a paid compute, how much money - a run costs.
    #
    # @param templates_or_collection_id [Array<String>, false, nil] template names, or one
    #   Collection id; a value naming a template wins over a Collection of that id, the order the
    #   task read its one argument in before this was extracted
    # @param external_system [String, nil] id, identifier or name of the importing system, e.g.
    #   'canto_dam'
    # @raise [RuntimeError] when external_system names no system or an ambiguous one - a typo would
    #   otherwise widen the run to every content, and the imageDescriptionPixie of #49225 pays a
    #   vision service per image
    # @return [BackfillScope]
    def backfill_scope(templates_or_collection_id: nil, external_system: nil)
      template_names = templates_or_collection_id.presence if templates_or_collection_id.present? && DataCycleCore::ThingTemplate.exists?(template_name: templates_or_collection_id)
      collection_id = templates_or_collection_id.presence if template_names.nil?

      things = DataCycleCore::Thing.all
      things = things.where(id: collection_thing_ids(collection_id)) if collection_id
      # imported_things, not a bare external_source_id: ExternalSystem#things is the join over
      # external_system_syncs, i.e. what it was delivered, and only this one is what it imported
      things = things.merge(DataCycleCore::ExternalSystem.find_unique_by_names_identifiers_or_ids!(external_system).imported_things) if external_system.present?

      thing_templates = DataCycleCore::ThingTemplate.all
      thing_templates = thing_templates.where(template_name: template_names) if template_names
      # the templates a narrowed set of contents actually uses: the task counts and walks one
      # template at a time, so every template left in costs a count over a scope with nothing in it
      thing_templates = thing_templates.where(template_name: things.distinct.pluck(:template_name)) if collection_id || external_system.present?

      BackfillScope.new(things:, thing_templates:)
    end

    # Reduces a rich text to the prose it carries, so a task that moved a text somewhere else
    # recognises it again on the next run.
    #
    # The entities are decoded after the tags are stripped, not before: String#strip_tags leaves
    # them literal ('<p>a&nbsp;b</p>'.strip_tags is "a&nbsp;b"), so a paragraph the editor wrote as
    # "gezielt&nbsp;Teilbäume" would never equal the same prose typed with a plain space, and a
    # migration comparing the two would store it a second time. Runs of Unicode whitespace collapse
    # for the same reason - U+00A0 and U+0020 differ as codepoints but not as prose.
    #
    # @param value [String, nil] rich text, with or without markup
    # @return [String, nil] the comparable prose, nil when nothing is left of it
    def comparable_text(value)
      HTMLEntities.new.decode(value.to_s.strip_tags).gsub(/[[:space:]]+/, ' ').strip.presence
    end

    def find_or_create_content(external_source: nil, external_key: nil, template_name: nil, data: nil)
      content = DataCycleCore::Thing.where(
        template_name:,
        external_source_id: external_source&.id,
        external_key:
      ).first

      unless content
        content = DataCycleCore::Thing.new(template_name:)

        content.created_at = Time.zone.now
        content.updated_at = content.created_at
        content.created_by = nil
        content.external_source_id = external_source&.id
        content.external_key = external_key
        content.save!(touch: false)

        content.set_data_hash(data_hash: data, new_content: true)
      end

      content
    end

    private

    # @param collection_id [String] id of a Collection, i.e. a StoredFilter or a WatchList
    # @return [Array<String>] the ids of the contents it holds
    def collection_thing_ids(collection_id)
      DataCycleCore::Collection.where(id: collection_id).flat_map { |collection| collection.things.pluck(:id) }.uniq
    end
  end
end
