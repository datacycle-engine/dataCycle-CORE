# frozen_string_literal: true

module DataCycleCore
  module TestData
    # Generates one complete dummy content record per creatable template: fills every
    # fillable attribute with random type-appropriate data, optionally sets a life cycle stage and
    # adds it to a default collection shared with all system_admins. Records are created by the
    # system (no user); translatable templates are filled in every requested locale. Opt-in (never
    # runs automatically) and safe in production.
    #
    # collection_id reaches any collection in the installation, a user's or an api one included, so
    # the Report names the collection it resolved: a wrong-but-existing id would otherwise produce a
    # run that looks entirely successful while random records sit in someone else's collection.
    #
    # Everything the caller names is resolved before the first record is created — life cycle stage,
    # template names, collection — and an unresolvable one raises. A partial dataset out of a set the
    # caller listed explicitly reads as success and is worth less than no dataset at all. Failures
    # that only surface while generating (fill, life cycle, collection membership) are reported, not
    # raised: those records exist and the rest of the run is still usable.
    #
    # Embedded templates are always out of scope: they have no record of their own and are
    # generated as part of the record they are embedded in. `include_non_creatable` widens the
    # selection to non-embedded templates that deliberately declare `creatable` off — not to
    # embedded ones, and not to the many templates that never declare the feature at all.
    #
    # Two-pass so required links resolve: pass 1 creates an empty row per template (valid
    # link targets), pass 2 fills each with a strict, complete data hash that may reference
    # any other dummy. Empty rows whose fill fails stay valid link targets and are reported.
    class Generator
      DEFAULT_COLLECTION = 'Testdaten'

      # @param collection_id [String, nil] id of an existing collection to add the records to; takes
      #   precedence over collection_name, which can only ever reach system-owned collections.
      # @param include_non_creatable [Boolean] also generate templates whose schema deliberately
      #   declares `creatable` off — `:creatable: ~` (killing an inherited `allowed: true`) or an
      #   explicit `allowed: false`. Those are the imported content types an installation does not let
      #   editors create, which is exactly why they may have no test data. Templates that never mention
      #   the feature stay out: `creatable?` is false for them too, but they are mostly overlay,
      #   aggregate and translation shapes for which a free-standing record is meaningless.
      def initialize(locales: nil, collection_name: DEFAULT_COLLECTION, collection_id: nil, max_depth: 4, life_cycle: nil, template_names: nil, include_non_creatable: false)
        @locales = Array.wrap(locales).map(&:to_sym).presence || I18n.available_locales
        @primary_locale = @locales.first
        @collection_name = collection_name
        @collection_id = collection_id.presence
        @max_depth = max_depth
        @life_cycle = life_cycle.presence
        @template_names = Array.wrap(template_names).presence
        @include_non_creatable = include_non_creatable
        @report = Report.new
        @life_cycle_stage_id = nil
      end

      # Runs the two-pass generation and returns a Report.
      def generate
        I18n.with_locale(@primary_locale) do
          resolve_life_cycle_stage!
          template_things = template_things_to_generate
          collection = resolve_collection!
          @report.note_collection(collection)
          entries = create_records(template_things)
          builder = ValueBuilder.new(max_depth: @max_depth)
          entries.each do |entry|
            fill(entry, builder)
            finalize(entry, collection)
          end
        end

        @report
      end

      private

      # Templates to generate: every creatable, non-embedded one — plus the deliberately
      # non-creatable ones with include_non_creatable — or exactly the requested names out of that
      # set. Narrowed in SQL when names were requested: the schemas are the bulk of a thing_templates
      # row and a Thing is instantiated per row kept, so there is no reason to load the ones the
      # caller did not ask for. Anything not returned is unmatched, which is what check! looks at.
      def template_things_to_generate
        thing_templates = DataCycleCore::ThingTemplate.without_embedded
        thing_templates = thing_templates.with_template_names(@template_names) if @template_names.present?
        template_things = thing_templates.template_things
        template_things.select! { |t| t.creatable?('all') || (@include_non_creatable && creatable_declared_off?(t)) }
        check_template_names!(template_things) if @template_names.present?
        template_things
      end

      # True when the schema says editors must not create this, rather than merely staying silent:
      # `features.creatable` is present and does not allow it (`:creatable: ~` or `allowed: false`).
      # A template that never declares the feature is not covered — see include_non_creatable.
      #
      # @param template [DataCycleCore::Thing, DataCycleCore::ThingTemplate] anything carrying the
      #   template schema; the selection passes template things, the unmatched path bare templates.
      def creatable_declared_off?(template)
        features = template.schema['features']

        features.is_a?(::Hash) && features.key?('creatable') && !features.dig('creatable', 'allowed')
      end

      # A requested name that resolved to nothing aborts the run, for the same reason an unknown
      # collection_id does: the caller named a set, and shipping a subset of it looks like success.
      # Every unmatched name is listed with the reason that applies to it, since the ways a name can
      # miss need different fixes. Bare templates, not template things — the reasons read the schema
      # and there is no point instantiating a Thing per name that is not going to be generated.
      #
      # @raise [ArgumentError] if any requested template name is not in the generated selection.
      def check_template_names!(template_things)
        unmatched = @template_names - template_things.map(&:template_name)
        return if unmatched.empty?

        known = DataCycleCore::ThingTemplate.with_template_names(unmatched).index_by(&:template_name)

        raise ArgumentError, unmatched.map { |name| "  - #{name}: #{unmatched_reason(known[name])}" }
          .unshift("cannot generate #{unmatched.size} of the #{@template_names.size} requested templates:").join("\n")
      end

      # Exhaustive over the reasons a template can be left out: unknown to the installation, plus the
      # three ways Content#creatable? returns false — embedded content type, creatable not allowed,
      # and a creatable scope that does not cover the 'all' scope the generator creates in.
      def unmatched_reason(template)
        return 'no such template' if template.nil?
        return 'embedded template — generated inside the record it is embedded in, never on its own' if template.schema['content_type'] == 'embedded'
        return 'not creatable — pass include_non_creatable to generate it anyway' if creatable_declared_off?(template)

        scope = template.schema.dig('features', 'creatable', 'scope')
        return "creatable only in scope #{Array.wrap(scope).join(', ')}, and the generator creates in scope `all`" if scope.present?

        'never declares the creatable feature, which include_non_creatable does not cover — declare `:creatable: ~` on the template to mark it deliberately non-creatable'
      end

      # Pass 1: one empty system-owned Thing per template (valid link targets for pass 2).
      def create_records(template_things)
        template_things.filter_map do |template_thing|
          thing = DataCycleCore::Thing.new(template_name: template_thing.template_name)
          # No `next add_failure(...)`: add_failure returns the truthy messages array, which
          # filter_map would keep as an entry and pass 2 would then subscript.
          if thing.template_missing?
            @report.add_failure(template_thing.template_name, 'template missing')
            next
          end

          thing.created_by = nil
          thing.save!(touch: false)
          { template_thing:, thing: }
        rescue StandardError => e
          @report.add_failure(template_thing.template_name, "create: #{e.message}")
          nil
        end
      end

      # Pass 2: fill the record with a complete, strictly-validated data hash. Translatable
      # templates are filled in every requested locale, untranslatable ones in the primary one.
      def fill(entry, builder)
        thing = entry[:thing]
        template_name = thing.template_name
        definitions = entry[:template_thing].property_definitions
        locales = thing.translatable? ? @locales : [@primary_locale]

        data_by_locale = {}
        skipped = nil
        locales.each do |locale|
          result = builder.call(definitions, exclude_id: thing.id)
          data_by_locale[locale] = result[:data]
          skipped ||= result[:skipped]
        end
        @report.add_skips(template_name, skipped)

        if thing.set_data_hash_with_translations(data_hash: translated_data_hash(thing, data_by_locale, locales), new_content: true, prevent_history: true, update_search_all: false)
          @report.add_success(template_name, data_by_locale[@primary_locale].keys)
        else
          entry[:failed] = true
          @report.add_failure(template_name, thing.errors.full_messages.first(5).join('; ').presence || 'validation failed')
        end
      rescue StandardError => e
        entry[:failed] = true
        @report.add_failure(entry[:template_thing].template_name, "fill: #{e.message}")
      end

      # Splits the per-locale data for set_data_hash_with_translations: per-locale scalar text
      # goes under translations, everything else (relations + untranslatable attributes) stays
      # shared in datahash. Embedded/linked must stay shared — set_data_hash_with_translations
      # drops them when nested under translations.
      def translated_data_hash(thing, data_by_locale, locales)
        primary = data_by_locale[@primary_locale]
        return { datahash: primary } if locales.size == 1

        per_locale_keys = thing.translatable_property_names.select { |name| primary[name].is_a?(String) }
        {
          datahash: primary.except(*per_locale_keys),
          translations: locales.index_with { |locale| data_by_locale[locale].slice(*per_locale_keys) }
        }
      end

      def finalize(entry, collection)
        return if entry[:failed]

        apply_life_cycle(entry[:thing])
        add_to_collection(collection, entry[:thing])
      end

      # Resolves the requested life cycle stage name to a classification id once. Does nothing
      # when no stage was requested or the feature is disabled; raises when the feature is
      # enabled but the named stage does not exist in the life cycle tree.
      def resolve_life_cycle_stage!
        return if @life_cycle.blank?
        return @report.note_life_cycle_disabled unless DataCycleCore::Feature::LifeCycle.enabled?

        @life_cycle_stage_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.dig(@life_cycle, :id)
        return if @life_cycle_stage_id.present?

        raise ArgumentError, "life cycle stage '#{@life_cycle}' not found in tree '#{DataCycleCore::Feature::LifeCycle.tree_label}'"
      end

      # Sets the resolved life cycle stage on a content whose template supports the feature.
      def apply_life_cycle(thing)
        return if @life_cycle_stage_id.nil?
        return unless DataCycleCore::Feature::LifeCycle.allowed?(thing)

        thing.set_life_cycle_classification(@life_cycle_stage_id, nil, true, true)
        @report.mark_life_cycle_set(thing.template_name)
      rescue StandardError => e
        @report.add_failure(thing.template_name, "life_cycle: #{e.message}")
      end

      # Resolved before the first record is created: an unknown id has to abort the run, not leave
      # randomly-filled records behind with no collection to find them by.
      #
      # @raise [ActiveRecord::RecordNotFound] if collection_id names no existing collection.
      def resolve_collection!
        return ensure_collection if @collection_id.blank?

        DataCycleCore::WatchList.find(@collection_id)
      end

      def ensure_collection
        return if @collection_name.blank?

        collection = DataCycleCore::WatchList.find_or_create_by!(full_path: @collection_name, user_id: nil) { |wl| wl.api = true }
        share_with_system_admins(collection)
        collection
      rescue StandardError => e
        @report.add_failure('(collection)', "collection: #{e.message}")
        nil
      end

      # The collection has no owner, so only a share makes it visible; sharing with the role covers
      # every current and future system_admin with a single row.
      def share_with_system_admins(collection)
        role = DataCycleCore::Role.system_admin
        return if role.nil? || collection.shared_roles.exists?(role.id)

        collection.shared_roles << role
      rescue StandardError => e
        @report.add_failure('(collection)', "share: #{e.message}")
      end

      def add_to_collection(collection, thing)
        return if collection.nil?

        collection.things << thing
      rescue StandardError => e
        @report.add_failure(thing.template_name, "collection: #{e.message}")
      end
    end
  end
end
