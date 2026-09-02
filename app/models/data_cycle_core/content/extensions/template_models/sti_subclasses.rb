# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module TemplateModels
        # One STI subclass per ThingTemplate (DataCycleCore::Thing::Poi, with template_name as the
        # inheritance column), so rows round-trip to the class of their template. This concern owns
        # generating them and resolving stored template values and constant references to them; what
        # a generated class carries is in GeneratedSubclass.
        #
        # Templates are database rows, so nothing can be generated while these classes load — a boot
        # without a usable connection is normal (db:create, asset builds). The subclasses are
        # generated on the first STI resolution instead, once per process, and singly on demand
        # afterwards.
        #
        # Every entry point hops to the STI root (base_class) first: AR resolves the type through
        # the relation's class (Thing::Uebersetzung.unscoped) and Ruby raises const_missing on
        # whichever class was referenced, while the generated constants and the init state live on
        # the root alone. Without the hop the lookup falls back to base_class, which AR then rejects
        # with SubclassNotFound ("... is not a subclass of ..."). Thing and Thing::History are
        # separate roots holding separate state.
        module StiSubclasses
          extend ActiveSupport::Concern

          included do
            self.inheritance_column = :template_name
            self.store_full_sti_class = false
            @sti_subclass_mutex = Mutex.new
          end

          class_methods do
            include Attributes::GeographicAttributes

            # :nodoc:
            def ensure_sti_subclasses_initialized_once!
              return base_class.ensure_sti_subclasses_initialized_once! unless sti_root_class?
              return if @sti_subclasses_initialized
              return unless thing_templates_available?

              # recorded before the flag is published: a thread that skips the init below must still
              # be able to map a constant it has not generated yet back to its template (const_missing)
              @sti_template_names = DataCycleCore::ThingTemplate.pluck(:template_name)
              @sti_subclasses_initialized = true

              create_sti_subclasses_from_thing_templates!
            end

            # :nodoc:
            def create_sti_subclasses_from_thing_templates!
              DataCycleCore::ThingTemplate.find_each do |template|
                create_sti_subclass_for_template_if_missing!(template)
              end
            end

            # :nodoc:
            def create_sti_subclass_for_template_if_missing!(template)
              return base_class.create_sti_subclass_for_template_if_missing!(template) unless sti_root_class?

              subclass_name = sti_subclass_name_for(template.template_name)
              return if subclass_name.blank? || const_defined?(subclass_name, false)

              subclass = build_sti_subclass(template)

              # the init above and the on-demand paths below generate classes concurrently (one
              # request thread resolves a template while another is still initializing), and a
              # second const_set would replace the class already instantiated records are instances
              # of. The lock claims the name only: the class is built before it is taken, so nothing
              # that autoloads or queries runs while it is held.
              @sti_subclass_mutex.synchronize do
                const_set(subclass_name, subclass) unless const_defined?(subclass_name, false)
              end
            end

            # Builds the STI subclass for a stored template value on demand when it was
            # not generated during the one-time bulk init — e.g. a ThingTemplate created
            # after init (common in tests, and runtime template imports outside
            # development, where no code reload is triggered).
            #
            # @param type_name [String, Symbol, nil] Raw STI value from persistence.
            # @return [void]
            def create_sti_subclass_for_type_if_missing!(type_name)
              return base_class.create_sti_subclass_for_type_if_missing!(type_name) unless sti_root_class?

              subclass_name = sti_subclass_name_for(type_name)
              return if subclass_name.blank? || const_defined?(subclass_name, false)

              template = DataCycleCore::ThingTemplate.find_by(template_name: type_name.to_s)
              create_sti_subclass_for_template_if_missing!(template) if template.present?
            end

            # Builds the STI subclass behind a constant reference that the one-time bulk init has not
            # generated yet: it publishes its flag before its first const_set, so a request thread
            # resolving a template while another thread is still initializing found the constant
            # missing. The editor fires one remote_render per embedded viewer, straight into that
            # window on a freshly booted (in development, freshly reloaded) process.
            #
            # The same recovery create_sti_subclass_for_type_if_missing! gives the persistence path,
            # keyed by the constant rather than the template name: a serialized {class:, id:} pair
            # (DataCycleCore::ParamsResolver, remote_render) carries only the camelized name, and
            # without this it constantizes to nil and the caller silently gets the raw hash back.
            #
            # @param const_name [Symbol, String] Referenced constant name.
            # @return [void]
            def create_sti_subclass_for_const_if_missing!(const_name)
              return base_class.create_sti_subclass_for_const_if_missing!(const_name) unless sti_root_class?
              return if const_defined?(const_name, false)

              template_name = sti_template_name_for_const(const_name, sti_template_names)
              template_name ||= sti_template_name_for_const(const_name, template_names_imported_since_init)

              create_sti_subclass_for_type_if_missing!(template_name) if template_name.present?
            end

            # Resolves the concrete STI class name for the stored template value.
            #
            # Synthetic / one-shot templates (no persisted ThingTemplate — e.g. the
            # bulk-edit "Generic" aggregate, or a stored value whose template was
            # deleted) generate no STI subclass. They resolve to the base class
            # instead of letting AR's compute_type walk the module nesting and pick
            # up an unrelated constant (e.g. the DataCycleCore::Generic importer
            # module), which AR would then reject with SubclassNotFound.
            #
            # @param type_name [String, Symbol, nil] Raw STI value from persistence.
            # @return [Class] Resolved STI class.
            def sti_class_for(type_name)
              ensure_sti_subclasses_initialized_once!
              create_sti_subclass_for_type_if_missing!(type_name)

              subclass_name = sti_subclass_name_for(type_name)
              return base_class unless subclass_name.present? && base_class.const_defined?(subclass_name, false)

              super(subclass_name)
            end

            # Resolves missing STI subclass constants on first direct constant access.
            #
            # @param const_name [Symbol] Missing constant name.
            # @return [Class] Resolved subclass when available.
            def const_missing(const_name)
              ensure_sti_subclasses_initialized_once!
              create_sti_subclass_for_const_if_missing!(const_name)
              return base_class.const_get(const_name, false) if base_class.const_defined?(const_name, false)

              super
            end

            private

            # The subclass for +template+, not yet registered as a constant.
            def build_sti_subclass(template)
              template_name = template.template_name.to_s

              subclass = Class.new(self) do
                include GeneratedSubclass

                define_singleton_method(:sti_name) { template_name }
              end

              define_geo_attributes_for(subclass, template, geometry_association_name:)

              subclass
            end

            # sti_subclass_name_for is not invertible (it transliterates and camelizes), so the template
            # names are scanned for the one +const_name+ is generated from.
            def sti_template_name_for_const(const_name, template_names)
              template_names.find { |name| sti_subclass_name_for(name) == const_name.to_s }
            end

            def sti_template_names
              Array.wrap(@sti_template_names)
            end

            # The names the init recorded go stale wherever a template is imported into a process that
            # has already initialized and is not reloaded afterwards: test, whose setup creates them
            # in-process, and production, where TemplateImporter's reload touch is development-only and
            # a worker already serving is never invalidated. Development is the exception — that touch
            # replaces Thing, so its init re-runs against the full set. Hence only a name the init did
            # not record is looked up again, the same allowance
            # create_sti_subclass_for_type_if_missing! makes on the persistence path.
            def template_names_imported_since_init
              return [] unless thing_templates_available?

              DataCycleCore::ThingTemplate.pluck(:template_name) - sti_template_names
            end

            def sti_subclass_name_for(template_name)
              # camelize (not classify) so plural-ish template names are not singularized,
              # which would mangle names and risk constant collisions. parameterize strips
              # blanks, so the camelized result has no spaces.
              #
              # Pin transliteration to a fixed locale: parameterize -> I18n.transliterate uses
              # the ACTIVE locale, so "Übersetzung" transliterates to "Uebersetzung" under :de
              # but "Ubersetzung" under :it/:sl. This method both generates the subclass constant
              # AND resolves it on every record instantiation (find_sti_class), which frequently
              # runs inside I18n.with_locale(target_locale) blocks (e.g. auto-translation). A
              # locale-dependent name would generate and look up different constants, so the
              # lookup falls back to the base class and AR raises SubclassNotFound. Pinning the
              # locale (equivalent to underscore_blanks with a stable locale) keeps the name
              # consistent across locales.
              template_name.to_s.underscore.parameterize(separator: '_', locale: I18n.default_locale).camelize
            end

            def sti_root_class?
              self == base_class
            end

            def thing_templates_available?
              DataCycleCore::ThingTemplate.table_exists?
            rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished, ActiveRecord::StatementInvalid
              false
            end

            def geometry_association_name
              return :geometries if reflect_on_association(:geometries).present?
              return :geometry_histories if reflect_on_association(:geometry_histories).present?

              nil
            end
          end
        end
      end
    end
  end
end
