# frozen_string_literal: true

require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260908090000_rename_classification_filters_to_concept_filters')

# [#41458] The YAML half of RenameClassificationFiltersToConceptFilters, which moves the same words in
# collections.parameters. Both halves read its one map, because a vocabulary only half moved fails
# silently: apply_single_filter! is a `return unless query.respond_to?(t)`, so a features.yml still
# asking for classification_alias_ids renders a dashboard chip that filters nothing, and a role
# denying classification_tree_ids through AdvancedFilterExceptType denies nothing.
class ConceptFilterUpgradeHelper
  # The word the cut moved away from, in the snake_case a call site spells a name in.
  CLASSIFICATION_NAME = '[a-z_0-9]*classification[a-z_0-9]*'
  RELATION_METHODS = 'includes|preload|eager_load|joins|left_joins|left_outer_joins|references'

  # Six shapes, because the plain call reaches 11 of the 41 files on its own: a call, a symbol to
  # proc, an association declaration, an active record symbol argument, a nested attributes key and
  # a table qualifier in SQL. `def self.` is a definition rather than a call, and the project
  # importers define a load_root_classifications of their own.
  CALL_SHAPES = /
    ([A-Z][\w:]*)?(?<!def\sself)\.(#{CLASSIFICATION_NAME})\b
    |&:(#{CLASSIFICATION_NAME})\b
    |(?:has_many|has_one|belongs_to)\s+:(#{CLASSIFICATION_NAME})\b
    |(?:#{RELATION_METHODS})\([^)]*?:(#{CLASSIFICATION_NAME})\b
    |\b(#{CLASSIFICATION_NAME}):\s*[{\[]
    |['"](#{CLASSIFICATION_NAME})\.
  /x

  class << self
    # @param root [Pathname] the project root
    # @return [Array<Pathname>] the configs whose vocabulary was moved
    def rename_configs(root)
      renames = renames_longest_first

      root.glob('config/**/*.yml').select do |path|
        content = path.read
        moved = renames.reduce(content) { |text, (old, new)| text.gsub(old, new) }
        next false if content == moved

        path.write(moved)
        true
      end
    end

    # Roles, stored filters and migrations written in ruby carry the same vocabulary, and rewriting
    # hand-written application code is not this step's business - name the files instead. The two fail
    # differently: a dropped filter name filters nothing and says nothing, because apply_single_filter!
    # is a `return unless query.respond_to?(t)`, while a dropped model constant raises NameError the
    # next time that code runs - late, but loudly.
    #
    # Projects keep this vocabulary in rake tasks, views and jbuilder templates as well as in plain
    # ruby, and under config/ as well as the three dirs this scan used to name. Measured at their
    # pre-cut refs over the 40 project checkouts that name a dropped constant at all:
    # {app,lib,db}/**/*.rb reaches 244 of those 326 files, and data-cycle-region-woerthersee is reached
    # by nothing but lib/tasks/woerthersee_tasks.rake. `jb` is a registered handler like `jbuilder`,
    # and data-cycle-kw renders one of its api v3 attributes from a .jb with no .jbuilder beside it.
    # `axlsx` is a template extension too, and the one no glob here reached: data-cycle-kw's
    # accommodation sheets call primary_classification_alias and data-cycle-porcia's member export
    # calls thing.classification_aliases, all three of them from a .axlsx and all three still live
    # after their project merged the port.
    #
    # @param root [Pathname] the project root
    # @return [Array<Pathname>] the files that still name a dropped filter, model or call
    def stale_files(root)
      applied = applied_versions
      dropped = dropped_filters

      root.glob('{app,config,lib,db}/**/*.{rb,rake,erb,jbuilder,jb,axlsx}').select do |path|
        next false if applied.include?(path.basename.to_s[/\A\d+/])

        content = path.read
        dropped.any? { |word| content.include?(word) } ||
          names_dropped_constant?(content) ||
          names_dropped_call?(content)
      end
    end

    private

    # Longest name first, so classification_alias_ids cannot eat the stem of a longer key that renames
    # to something other than its own prefix.
    def renames_longest_first
      RenameClassificationFiltersToConceptFilters::FILTER_RENAMES.sort_by { |old, _| -old.length }
    end

    # Matched as bare substrings, so advanced_classification_alias_ids and
    # not_classification_alias_ids_with_subtree are reached too.
    def dropped_filters
      RenameClassificationFiltersToConceptFilters::FILTER_RENAMES.keys
    end

    # The model half asks the booted app which constants are gone rather than reading the cut
    # migration's two table lists, because those tables answer a different question than the code
    # does: DataCycleCore::ClassificationContent is dropped by a raw DROP TABLE and is in neither of
    # them, while every Classification* constant that survives the cut contains a needle they yield.
    # concept_filter_upgrade_helper_test.rb names both sets.
    def names_dropped_constant?(content)
      content.scan(/DataCycleCore::[A-Z]\w*/).uniq.any? do |const|
        const.include?('Classification') &&
          !DataCycleCore.const_defined?(const.delete_prefix('DataCycleCore::'), false)
      end
    end

    # An association carries neither a `def` nor a constant at its call site, so both checks above
    # pass `thing.classification_aliases` and `includes(:classifications)` in silence - over the 30
    # host project branches they named 0 of the 41 files that still called one. The question the
    # constant half asks works here too: a classification-flavoured name that no model answers to
    # any more is one the cut took away. The dropped methods come with it - `primary_classification`
    # and `classification_ids` among them - which fail the same way and are just as invisible.
    def names_dropped_call?(content)
      called_names(content).any? { |name| known_names.exclude?(name) }
    end

    # `scan` yields one group per shape, and the first of them is the call shape's receiver: a call
    # on a constant belongs to names_dropped_constant?, which judges the constant itself. Keeping
    # those out is what lets the project importers call ImportFunctions.import_classifications,
    # which the cut keeps, without being named for it.
    def called_names(content)
      content.scan(CALL_SHAPES).filter_map { |groups| groups.compact.first unless groups.first }.uniq
    end

    # Every name a model still answers to, which is what keeps this half free of a list of its own:
    # an association reader is an instance method like any other. DataCycleCore's own accessors come
    # with them because a project initializer calls them by name, on a `config` that is DataCycleCore.
    def known_names
      @known_names ||= begin
        eager_load_models

        (ActiveRecord::Base.descendants.flat_map { |model| model.instance_methods + model.methods } +
          DataCycleCore.singleton_class.instance_methods).to_set(&:to_s)
      end
    end

    # dc:upgrade runs on every container start, so a project that still subclasses a dropped model
    # must not lose the rest of the upgrade to the NameError that raises here. What loaded before it
    # answers most of the question, and the models that did not cost false positives, not silence.
    def eager_load_models
      Rails.application.eager_load!
    rescue NameError
      nil
    end

    # A migration that already ran cannot raise again, and dc:upgrade runs on every container start -
    # naming those on every boot is how a warning stops being read.
    #
    # Two of those runs have no database to ask: the update_project CI job declares no postgres
    # service, and a project's first container start reaches dc:upgrade before db:create. No
    # migration has run in either, so an empty list is both the true answer and the one that keeps
    # the raise from taking the remaining upgrade steps with it.
    def applied_versions
      connection = ActiveRecord::Base.connection

      {
        'schema_migrations' => 'SELECT version FROM schema_migrations',
        'data_migrations' => 'SELECT version FROM data_migrations'
      }.flat_map { |table, sql| connection.table_exists?(table) ? connection.select_values(sql) : [] }
    rescue ActiveRecord::NoDatabaseError, ActiveRecord::ConnectionNotEstablished
      []
    end
  end
end
