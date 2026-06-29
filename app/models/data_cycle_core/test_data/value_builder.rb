# frozen_string_literal: true

module DataCycleCore
  module TestData
    # Builds a strict-valid data hash for a template's property definitions, filling every
    # fillable attribute with type-appropriate random data. Recurses into embedded/object
    # properties (depth-limited) and samples classifications/links/assets from the database.
    #
    # Properties it cannot satisfy (empty classification tree, no matching asset, no link
    # target, pattern-constrained string, …) are left out and collected in :skipped so the
    # caller can report them.
    class ValueBuilder
      # Types we never synthesize: auto-generated, internal, or unsafe to fabricate
      # (oembed = live network call, timeseries/collection = out of scope, key/slug = derived).
      SKIPPED_TYPES = ['key', 'slug', 'timeseries', 'oembed', 'collection'].freeze

      def initialize(locale: I18n.locale, max_depth: 4, include_linked: true, asset_source: AssetSource.new)
        @locale = locale
        @max_depth = max_depth
        @include_linked = include_linked
        @asset_source = asset_source
        @concept_cache = {}
        @linked_cache = {}
      end

      # @param exclude_id [String, nil] content id to keep out of link targets (no self-links).
      # @return [Hash] { data: <data_hash>, skipped: [{ property:, type:, reason: }] }
      def call(property_definitions, exclude_id: nil)
        @exclude_id = exclude_id
        skipped = []
        data = build(property_definitions, depth: 0, path: +'', skipped:)
        { data:, skipped: }
      end

      private

      def build(definitions, depth:, path:, skipped:)
        fillable(definitions).each_with_object({}) do |(name, definition), data|
          value = value_for(name, definition, depth, "#{path}#{name}", skipped)
          data[name] = value unless value.nil?
        end
      end

      def fillable(definitions)
        definitions.reject do |name, definition|
          internal_names.include?(name) ||
            definition.key?('virtual') ||
            definition.key?('compute') ||
            definition['link_direction'] == 'inverse' ||
            overlay_attribute?(definition) ||
            edit_disabled?(definition) ||
            SKIPPED_TYPES.include?(definition['type'])
        end
      end

      # Overlay-derived attributes (<attr>_override/_add/_overlay) all carry overlay_for;
      # they belong to imported content, not a fresh record.
      def overlay_attribute?(definition)
        definition.dig('features', 'overlay', 'overlay_for').present?
      end

      # Attributes the editor cannot set (explicitly disabled, or not visible for editing,
      # which the template build flags as ui.edit.disabled) are left to defaults/the system.
      def edit_disabled?(definition)
        definition.dig('ui', 'edit', 'disabled').to_s == 'true'
      end

      def internal_names
        @internal_names ||= DataCycleCore::Content::Content::INTERNAL_PROPERTY_NAMES +
                            DataCycleCore::Content::Content::DUMMY_PROPERTY_NAMES
      end

      def value_for(name, definition, depth, path, skipped)
        case definition['type']
        when 'string', 'text' then string_value(name, definition, path, skipped)
        when 'number' then number_value(definition)
        when 'boolean' then RandomSource.boolean
        when 'date' then RandomSource.date(after: min_validation(definition)).iso8601
        when 'datetime' then RandomSource.datetime(after: min_validation(definition)).iso8601
        when 'geographic' then RandomSource.wkt(definition.dig('ui', 'edit', 'type'))
        when 'classification' then classification_value(definition, path, skipped)
        when 'asset' then asset_value(definition, path, skipped)
        when 'schedule', 'opening_time' then schedule_value
        when 'object' then object_value(definition, depth, path, skipped)
        when 'embedded' then embedded_value(definition, depth, path, skipped)
        when 'linked' then linked_value(definition, path, skipped)
        when 'table' then table_value
        else skip(skipped, path, definition['type'], 'unsupported type')
        end
      end

      # --- scalars -------------------------------------------------------------

      def string_value(name, definition, path, skipped)
        validations = definition['validations'] || {}

        if (pattern = validations['pattern']).present?
          return pattern_string(pattern) || skip(skipped, path, 'string', "unsatisfiable pattern (#{pattern})")
        end

        if (format = validations['format']).present?
          return formatted_string(format) || skip(skipped, path, 'string', "unsupported format '#{format}'")
        end

        RandomSource.constrained_string(min: validations['min'], max: validations['max'], as_title: title?(name, definition))
      end

      # Only formats with a real validator method (the String validator has none for 'email').
      def formatted_string(format)
        case format
        when 'uuid' then SecureRandom.uuid
        when 'url', 'soft_url' then "https://example.com/#{RandomSource.word}-#{RandomSource.integer(max: 9999)}"
        when 'telephone_din5008' then "+43 1 #{RandomSource.integer(min: 100_000, max: 999_999)}"
        end
      end

      # First candidate that fully matches the pattern, replicating the String validator's
      # own check (regex from expression[1..-2], whole-string match) so a hit is always valid.
      def pattern_string(expression)
        regex = Regexp.new(expression[1..-2])
        pattern_candidates.find { |c| (m = c.match(regex)) && m.offset(0) == [0, c.size] }
      rescue RegexpError
        nil
      end

      def pattern_candidates
        hh = rand(0..23).to_s.rjust(2, '0')
        mm = rand(0..59).to_s.rjust(2, '0')
        ss = rand(0..59).to_s.rjust(2, '0')
        ["#{hh}:#{mm}", "#{hh}:#{mm}:#{ss}", RandomSource.integer(max: 99).to_s,
         RandomSource.word, RandomSource.word.upcase, SecureRandom.uuid, "https://example.com/#{RandomSource.word}"]
      end

      def number_value(definition)
        validations = definition['validations'] || {}
        if validations['format'] == 'integer'
          RandomSource.integer(min: validations['min'] || 1, max: validations['max'] || 1000)
        else
          RandomSource.decimal(min: validations['min'] || 0, max: validations['max'] || 1000)
        end
      end

      def min_validation(definition)
        definition.dig('validations', 'min')
      end

      def title?(name, definition)
        name == 'name' || definition.dig('ui', 'is_title') == true
      end

      # --- classification / asset / linked ------------------------------------

      def classification_value(definition, path, skipped)
        ids = concept_ids(definition['tree_label'], definition['universal'])
        return skip(skipped, path, 'classification', classification_reason(definition)) if ids.empty?

        ids.sample(reference_count(definition, ids.size))
      end

      def classification_reason(definition)
        definition['tree_label'].present? ? "empty tree '#{definition['tree_label']}'" : 'no assignable concepts'
      end

      def concept_ids(tree_label, universal)
        cache_key = tree_label || (universal ? :__universal__ : :__none__)
        @concept_cache[cache_key] ||= load_concept_ids(tree_label, universal)
      end

      def load_concept_ids(tree_label, universal)
        scope = if tree_label.present?
                  DataCycleCore::Concept.for_tree(tree_label)
                elsif universal
                  DataCycleCore::Concept.all
                else
                  DataCycleCore::Concept.none
                end
        scope.assignable.limit(200).pluck(:classification_id)
      rescue StandardError
        []
      end

      # A single asset id string: the asset setter treats an Array as Asset objects (calling
      # .id on each), so an id must be passed bare, not wrapped in an array.
      def asset_value(definition, path, skipped)
        asset_type = definition['asset_type']
        id = @asset_source.id_for(asset_type)
        return skip(skipped, path, 'asset', "no #{asset_type.presence || 'image'} asset available") if id.nil?

        id
      end

      def linked_value(definition, path, skipped)
        return skip(skipped, path, 'linked', 'linking disabled') unless @include_linked

        ids = linked_candidates(definition) - Array.wrap(@exclude_id)
        return skip(skipped, path, 'linked', 'no candidate contents') if ids.empty?

        ids.first(reference_count(definition, ids.size))
      end

      def linked_candidates(definition)
        template_names = Array.wrap(definition['template_name'])
        cache_key = template_names.presence || :__any__
        @linked_cache[cache_key] ||= load_linked_candidates(template_names)
      end

      def load_linked_candidates(template_names)
        scope = if template_names.present?
                  DataCycleCore::Thing.where(template_name: template_names)
                else
                  DataCycleCore::Thing.where.not(content_type: 'embedded')
                end
        scope.limit(50).pluck(:id)
      rescue StandardError
        []
      end

      # References to emit: at least the required min (or 1, for a complete record), capped
      # by an optional max and by what is actually available.
      def reference_count(definition, available)
        validations = definition['validations'] || {}
        desired = [validations['min'].to_i, 1].max
        desired = [desired, validations['max'].to_i].min if validations['max'].present?
        [desired, available].min
      end

      # --- schedule / object / embedded / table -------------------------------

      def schedule_value
        start = (Time.zone.now + RandomSource.integer(min: 1, max: 30).days).change(hour: 9)
        zone = Time.zone&.name || 'Europe/Vienna'
        [{
          'start_time' => { 'time' => start.strftime('%Y-%m-%d %H:%M'), 'zone' => zone },
          'end_time' => { 'time' => (start + 2.hours).strftime('%Y-%m-%d %H:%M'), 'zone' => zone },
          'duration' => 7200
        }]
      end

      def table_value
        [['Spalte 1', 'Spalte 2'], [RandomSource.title, RandomSource.title]]
      end

      def object_value(definition, depth, path, skipped)
        properties = definition['properties']
        return nil if properties.blank?

        data = build(properties, depth: depth + 1, path: "#{path}.", skipped:)
        enforce_daterange!(data, definition)
        data.presence
      end

      # Object-level daterange validation requires the 'from' field <= the 'to' field;
      # the two dates are filled independently, so order them after the fact.
      def enforce_daterange!(data, definition)
        range = definition.dig('validations', 'daterange')
        from_key = range && range['from']
        to_key = range && range['to']
        return if from_key.blank? || to_key.blank? || data[from_key].blank? || data[to_key].blank?

        from = comparable_time(data[from_key])
        to = comparable_time(data[to_key])
        data[from_key], data[to_key] = data[to_key], data[from_key] if from && to && from > to
      end

      def comparable_time(value)
        value.to_datetime
      rescue ArgumentError, TypeError
        nil
      end

      def embedded_value(definition, depth, path, skipped)
        return skip(skipped, path, 'embedded', "max depth #{@max_depth} reached") if depth >= @max_depth

        template_names = Array.wrap(definition['template_name'])
        return skip(skipped, path, 'embedded', 'no template_name') if template_names.blank?

        template = internal_template(template_names.first)
        return skip(skipped, path, 'embedded', "template '#{template_names.first}' not found") if template.nil?

        item = build(template.property_definitions, depth: depth + 1, path: "#{path}[0].", skipped:)
        return skip(skipped, path, 'embedded', 'no fillable sub-properties') if item.blank?

        item['template_name'] = template_names.first if template_names.size > 1
        [item]
      end

      def internal_template(name)
        DataCycleCore::DataHashService.get_internal_template(name)
      rescue StandardError
        nil
      end

      def skip(skipped, path, type, reason)
        skipped << { property: path, type:, reason: }
        nil
      end
    end
  end
end
