# frozen_string_literal: true

module DataCycleCore
  module TestData
    # Generates one complete dummy content record per creatable template: fills every
    # fillable attribute with random type-appropriate data, optionally sets a life cycle
    # stage and adds it to a default collection. Records are created by the system (no user);
    # translatable templates are filled in every requested locale. Opt-in (never runs
    # automatically) and safe in production.
    #
    # Two-pass so required links resolve: pass 1 creates an empty row per template (valid
    # link targets), pass 2 fills each with a strict, complete data hash that may reference
    # any other dummy. Empty rows whose fill fails stay valid link targets and are reported.
    class Generator
      DEFAULT_COLLECTION = 'Testdaten'

      def initialize(locales: nil, collection_name: DEFAULT_COLLECTION, max_depth: 4, life_cycle: nil, template_names: nil)
        @locales = Array.wrap(locales).map(&:to_sym).presence || I18n.available_locales
        @primary_locale = @locales.first
        @collection_name = collection_name
        @max_depth = max_depth
        @life_cycle = life_cycle.presence
        @template_names = Array.wrap(template_names).presence
        @report = Report.new
        @life_cycle_stage_id = nil
      end

      # Runs the two-pass generation and returns a Report.
      def generate
        I18n.with_locale(@primary_locale) do
          resolve_life_cycle_stage!
          entries = create_records(creatable_template_things)
          builder = ValueBuilder.new(max_depth: @max_depth)
          entries.each { |entry| fill(entry, builder) }
          collection = ensure_collection
          entries.each { |entry| finalize(entry, collection) }
        end

        @report
      end

      private

      def creatable_template_things
        template_things = DataCycleCore::ThingTemplate.without_embedded.template_things.select { |t| t.creatable?('all') }
        template_things.select! { |t| @template_names.include?(t.template_name) } if @template_names
        template_things
      end

      # Pass 1: one empty system-owned Thing per template (valid link targets for pass 2).
      def create_records(template_things)
        template_things.filter_map do |template_thing|
          thing = DataCycleCore::Thing.new(template_name: template_thing.template_name)
          next @report.add_failure(template_thing.template_name, 'template missing') if thing.template_missing?

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

      def ensure_collection
        return if @collection_name.blank?

        DataCycleCore::WatchList.find_or_create_by!(full_path: @collection_name, user_id: nil) { |wl| wl.api = true }
      rescue StandardError => e
        @report.add_failure('(collection)', "collection: #{e.message}")
        nil
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
