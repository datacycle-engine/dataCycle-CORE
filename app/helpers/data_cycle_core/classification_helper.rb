# frozen_string_literal: true

module DataCycleCore
  module ClassificationHelper
    VISIBILITY_ICONS = {
      'list' => 'fa-th-list',
      'tree_view' => 'fa-sitemap',
      'tile' => 'fa-th'
    }.freeze

    # Memoized per render: a helper instance lives for one template render, and one form asks this
    # once per classification attribute - the annotationPixie's editors alone ask it once per
    # eligible concept scheme, all of them for the same universal_classifications tree label.
    def concept_scheme_has_concepts?(scheme_name)
      cache = (@concept_scheme_has_concepts ||= {})
      return cache[scheme_name] if cache.key?(scheme_name)

      cache[scheme_name] = DataCycleCore::Concept.for_tree(scheme_name).exists?
    end

    def concept_title(concept)
      return 'DELETED' unless concept.is_a?(DataCycleCore::Concept)

      concept.internal_name.presence || concept.external_key.presence || 'NO_NAME'
    end

    # Read from the materialised path rather than through +concept_scheme+: the callers preload
    # :concept_path for the full path anyway, and concept_paths.full_path_names ends with the
    # scheme's name (e.g. {Adelberg, …, Deutschland, "Administrative Einheiten"}).
    def concept_scheme_name(concept)
      concept&.concept_path&.full_path_names&.last
    end

    # #43524: display texts for the concept-usage chip on the saved-searches page - takes the
    # already-resolved record (see StoredFilter.classification_usage_record) so this stays pure
    # presentation logic - and mirrors how a concept filter tag looks elsewhere (dimension
    # label + selected value): [scheme_name, concept_title], e.g. ["Inhaltstypen",
    # "Veranstaltung"]. For a concept_scheme (the whole tree, not a single concept) the scheme
    # name is still the dimension label, but there is no narrower selection, so the value falls back
    # to a generic "all" text instead of repeating the scheme name as if it were a specific selection.
    def classification_usage_titles(record)
      case record
      when DataCycleCore::Concept
        [concept_scheme_name(record), concept_title(record)]
      when DataCycleCore::ConceptScheme
        [record.name, t('data_cycle_core.stored_searches.classification_usage_all', locale: active_ui_locale)]
      end
    end

    def concept_path_classes(concept)
      return if concept&.concept_path&.full_path_names.nil?

      scheme_name = concept_scheme_name(concept)
      concept
        .concept_path
        .full_path_names
        .except(scheme_name)
        .map { |c_name| "#{scheme_name}_#{c_name}".underscore_blanks }
        .join(' ')
    end

    def concept_color_style(concept)
      return unless concept&.color?

      "--classification-color: #{concept.color};"
    end

    # Builds the tooltip markup shared by every concept representation (tags, editor labels,
    # filter items, select2 options and the classifications JSON endpoints). Sections are ordered from
    # identity to detail: full path, external URI, description, translations.
    #
    # The external URI (#27657) is what tells near-identically named concepts apart while mapping them,
    # so it is labelled with the model's own attribute translation rather than printed bare - its values
    # are not always URL-shaped, some external systems store foreign ids in it. It stays plain text on
    # purpose: the shared tooltip element is not interactive, so a link would not be clickable. It is a
    # technical detail, so it is gated on :show_uri, which only system_admin holds - asked of the class
    # rather than the record, because the section is a global capability, not a per-concept one.
    #
    # @param concept [DataCycleCore::Concept, nil] nil where a caller looks a concept up by id
    # @return [String, nil] tooltip markup for data-dc-tooltip, sanitized again client side
    def concept_tooltip(concept)
      return if concept.nil?

      tooltip_html = []
      uri = concept.uri

      tooltip_html << tag.div(concept.full_path, class: 'tag-full-path') if concept.full_path.present?

      if uri.present? && can?(:show_uri, DataCycleCore::Concept)
        tooltip_html << tag.div(
          safe_join([tag.span("#{DataCycleCore::Concept.human_attribute_name(:uri, locale: active_ui_locale)}:", class: 'tag-uri-header'), uri], ' '),
          class: 'tag-uri'
        )
      end

      I18n.with_locale(concept.first_available_locale(active_ui_locale)) do
        tooltip_html << tag.div(sanitize(concept.description), class: 'tag-description') if concept.description.present?
      end

      if concept.name_i18n.keys.many?
        tooltip_html << tag.div(
          tag.span(I18n.t('classifications.tooltip_translations', locale: active_ui_locale), class: 'tag-translations-header') +
          tag.ul(
            safe_join(
              concept
                .name_i18n
                .each_with_object({}) { |(k, v), h|
                  (h[v] ||= []) << k
                }
                .transform_values { |v| v.sort.join(', ') }
                .sort_by { |_k, v| v }
                .map { |k, v| tag.li(ActionView::OutputBuffer.new("#{k} #{tag.span("(#{v})", class: 'tag-translations-locales')}")) }
            ),
            class: 'tag-translations-list'
          ),
          class: 'tag-translations'
        )
      end

      tooltip_html.compact.join('<br>')
    end

    def concept_filter_items(scheme_name, order_by = nil)
      return DataCycleCore::Concept.none if scheme_name.blank?

      DataCycleCore::Concept
        .for_tree(scheme_name)
        .assignable
        .includes(:concept_path, children: [:concept_path, { children: [:concept_path, :children] }])
        .order(order_by)
    end

    def async_concept_select_options(value)
      value = Array.wrap(value).compact

      return options_for_select([]) if value.blank?

      options_for_select(value.map { |c| concept_select_option(c) }, value.pluck(:id))
    end

    def simple_concept_select_options(value, concept_items)
      value = Array.wrap(value).compact

      options_for_select(
        (concept_items + value)
          .uniq(&:id)
          .reject { |c| concept_scheme_name(c) == 'Inhaltstypen' && DataCycleCore.excluded_filter_classifications.include?(c.internal_name) }
          .map { |c| concept_select_option(c) },
        value.pluck(:id)
      )
    end

    def classification_select_config(key, definition, options, content, additional_options = {})
      single_select = definition.dig('ui', 'edit', 'options', 'multiple') == false || definition.dig('validations', 'max') == 1

      {
        multiple: !single_select,
        include_blank: single_select,
        disabled: !attribute_editable?(key, definition, options, content),
        class: 'multi-select',
        data: {
          allow_clear: definition.dig('validations', 'required') != true,
          tree_label: definition['tree_label'],
          max: 20,
          placeholder: '',
          find_path: find_classifications_path,
          search_path: search_classifications_path
        },
        id: "#{options&.dig(:prefix)}#{sanitize_to_id(key)}"
      }.with_indifferent_access
        .merge(additional_options)
        .merge(definition.dig('ui', 'edit', 'options')&.except('class') || {})
        .tap { |h| h['class'] = "#{h['class']} #{definition.dig('ui', 'edit', 'options', 'class')}".squish }
    end

    def group_key_for_concept_scheme(concept_scheme, external_systems)
      return external_systems[concept_scheme.external_system_id]&.name || concept_scheme.external_system_id if concept_scheme.external_system_id.present?

      external_systems.values
        .filter { |s|
        concept_scheme.name.to_s.downcase.start_with?(s.name.to_s.downcase) ||
          concept_scheme.name.to_s.downcase.start_with?(s.identifier.to_s.downcase)
      }
        .min_by { |s|
        [
          DidYouMean::Levenshtein.distance(concept_scheme.name.to_s.downcase, s.name.to_s.downcase),
          DidYouMean::Levenshtein.distance(concept_scheme.name.to_s.downcase, s.identifier.to_s.downcase)
        ].min
      }&.name || (concept_scheme.name.split(' - ').many? ? concept_scheme.name.split(' - ').first : nil)
    end

    def grouped_concept_schemes(concept_schemes)
      external_systems = DataCycleCore::ExternalSystem.all.index_by(&:id)

      concept_schemes
        .group_by { |concept_scheme| group_key_for_concept_scheme(concept_scheme, external_systems) }
        .sort_by { |group_key, _| group_key.to_s.downcase }
        .to_h
        .transform_values { |schemes| schemes.sort_by { |cs| cs.name.to_s.downcase } }
    end

    # What gravity_ui_editor.js reads off data-gravity-info: the Gravity concepts as
    # {gravity, id, name}, the gravity taken from the fragment of the concept's uri.
    # @return [String] JSON
    def gravity_concepts_json
      DataCycleCore::Concept.for_tree('Gravity').map { |concept|
        I18n.with_locale(concept.first_available_locale) do
          { gravity: URI(concept.uri).fragment, id: concept.id, name: concept.name }
        end
      }.to_json
    end

    def concept_scheme_ccc_count(concept_scheme, collection, link_type)
      DataCycleCore::CollectedConceptContent.where(
        link_type:,
        concept_scheme_id: concept_scheme.id,
        thing_id: collection.things.reorder(nil).select(:id)
      ).distinct.count(:thing_id)
    end

    def matched_concept_path(name, matches)
      return name if matches.blank? || name.blank?

      matched_name = ''
      rest = name.to_s

      matches.each do |m|
        index = rest =~ Regexp.new(Regexp.escape(m), true)
        next if index.nil?

        index_end = index + m.size
        matched_name += rest[0...index]
        matched_name += "<mark>#{rest[index...index_end]}</mark>"
        rest = rest[index_end..].to_s
      end

      matched_name + rest
    end

    def concept_scheme_visibility_icon(visibility)
      icon_class = VISIBILITY_ICONS[visibility] || 'fa-info-circle'

      tag.i(
        class: "fa #{icon_class}",
        aria_hidden: 'true',
        data: {
          dc_tooltip: t("classification_visibilities.entry_tooltips.#{visibility}", locale: active_ui_locale)
        }
      )
    end

    def grouped_concept_scheme_visibilities(concept_scheme)
      DataCycleCore::ConceptScheme.grouped_visibilities.map do |group, visibilities|
        {
          key: group,
          selected: group == DataCycleCore::ConceptScheme.grouped_visibilities.keys.first,
          identifier: "cs-visibility-group-#{group}-#{concept_scheme.id}",
          title: t("classification_visibilities.groups.#{group}", locale: active_ui_locale),
          tooltip: t("classification_visibilities.group_tooltips.#{group}", locale: active_ui_locale),
          visibilities: visibilities
        }
      end
    end

    private

    def concept_select_option(concept)
      [
        concept.internal_name,
        concept.id,
        {
          data: {
            dc_tooltip: concept_tooltip(concept),
            full_path: concept.full_path
          },
          disabled: !concept.assignable
        }
      ]
    end
  end
end
