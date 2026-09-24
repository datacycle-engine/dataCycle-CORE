# frozen_string_literal: true

require 'test_helper'
require 'rake_helpers/concept_filter_upgrade_helper'
require DataCycleCore::Engine.root.join('db', 'data_migrate', '20260908090000_rename_classification_filters_to_concept_filters')
require DataCycleCore::Engine.root.join('db', 'migrate', '20260907120000_replace_classifications_with_concepts')

module DataCycleCore
  # [#41458] The upgrade step is the YAML half of RenameClassificationFiltersToConceptFilters, so the
  # shapes below are the ones the 22 project checkouts that carried the old vocabulary actually use:
  # the word appears as a hash key with and without a leading colon, as a list item, as a value, and
  # under a not_ prefix - a needle anchored on `:key:` reaches only the first of those.
  class ConceptFilterUpgradeHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def rename_configs(root)
      ConceptFilterUpgradeHelper.rename_configs(Pathname.new(root))
    end

    def stale_files(root)
      root = Pathname.new(root)
      ConceptFilterUpgradeHelper.stale_files(root).map { |path| path.relative_path_from(root).to_s }
    end

    def write(root, path, content)
      full = File.join(root, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, content)
      full
    end

    def in_project(&)
      Dir.mktmpdir(&)
    end

    # The migration anchors its needles on `"t": "…"` including the closing quote, so its own map may
    # be in any order and is. The helper matches bare words, so it has to impose one - handing it the
    # worst order there is proves it does.
    def with_renames(map)
      previous = RenameClassificationFiltersToConceptFilters::FILTER_RENAMES
      replace_renames(map)
      yield
    ensure
      replace_renames(previous)
    end

    def replace_renames(map)
      RenameClassificationFiltersToConceptFilters.send(:remove_const, :FILTER_RENAMES)
      RenameClassificationFiltersToConceptFilters.const_set(:FILTER_RENAMES, map)
    end

    test 'moves every shape the project checkouts use, at any depth under config' do
      in_project do |root|
        features = write(root, 'config/configurations/features.yml', <<~YAML)
          :advanced_filter:
            :classification_alias_ids: all
            :classification_tree_ids: true
          #  :classification_tree_ids: commented out, and still wrong once uncommented
          :permanent_advanced:
            - :type: classification_alias_ids
        YAML
        role = write(root, 'config/configurations/staging/permissions/roles/guest.yml', <<~YAML)
          advanced_filter:
            parameters:
              - - :advanced_attributes
                - :classification_tree_ids
              - classification_alias_ids: [Inhaltstypen]
        YAML
        definition = write(root, 'config/data_definitions/events/event.yml', <<~YAML)
          :image:
            :stored_filter:
              - :not_classification_alias_ids_with_subtree:
                  - "f2279aab-2b86-46bc-8ab1-02738507e4f9"
        YAML

        rename_configs(root)

        assert_equal <<~YAML, File.read(features)
          :advanced_filter:
            :concept_ids: all
            :concept_scheme_ids: true
          #  :concept_scheme_ids: commented out, and still wrong once uncommented
          :permanent_advanced:
            - :type: concept_ids
        YAML
        assert_equal <<~YAML, File.read(role)
          advanced_filter:
            parameters:
              - - :advanced_attributes
                - :concept_scheme_ids
              - concept_ids: [Inhaltstypen]
        YAML
        assert_equal <<~YAML, File.read(definition)
          :image:
            :stored_filter:
              - :not_concept_ids_with_subtree:
                  - "f2279aab-2b86-46bc-8ab1-02738507e4f9"
        YAML
      end
    end

    test 'renames the longest name first, whatever order the map arrives in' do
      # with_classification_alias_ids_without_recursion is the one entry whose replacement is not its
      # own prefix plus the rest: reached by classification_alias_ids first it comes out as
      # with_concept_ids_without_recursion, a name Filter::Search does not answer to
      shortest_first = RenameClassificationFiltersToConceptFilters::FILTER_RENAMES
        .sort_by { |old, _| old.length }.to_h.freeze

      in_project do |root|
        path = write(root, 'config/configurations/features.yml', <<~YAML)
          - :with_classification_alias_ids_without_recursion: true
          - :classification_alias_ids_without_subtree_with_related: true
          - :classification_alias_ids_with_subtree: true
          - :classification_alias_ids_related: true
        YAML

        with_renames(shortest_first) { rename_configs(root) }

        assert_equal <<~YAML, File.read(path)
          - :concept_ids_without_subtree: true
          - :concept_ids_without_subtree_with_related: true
          - :concept_ids_with_subtree: true
          - :concept_ids_related: true
        YAML
      end
    end

    test 'leaves a config that names none of them byte for byte alone, and runs again as a no-op' do
      in_project do |root|
        untouched = write(root, 'config/configurations/main_config.yml', ":classification_trees:\n  - Inhaltstypen\n")
        renamed = write(root, 'config/configurations/features.yml', ":classification_tree_ids: true\n")

        rename_configs(root)

        assert_equal ":classification_trees:\n  - Inhaltstypen\n", File.read(untouched)
        assert_equal ":concept_scheme_ids: true\n", File.read(renamed)

        before = File.mtime(renamed)

        assert_empty rename_configs(root)
        assert_equal before, File.mtime(renamed), 'a second run rewrote a file it had already moved'
      end
    end

    test 'names the ruby role definitions it will not rewrite' do
      in_project do |root|
        write(root, 'app/extensions/permissions/roles/standard.rb', <<~RUBY)
          can :show, :advanced_filter, AdvancedFilterExceptType.new([:backend], [:advanced_attributes, :classification_tree_ids])
        RUBY
        write(root, 'app/extensions/permissions/roles/clean.rb', "can :show, :advanced_filter\n")

        stale = stale_files(root)

        assert_includes stale, 'app/extensions/permissions/roles/standard.rb'
        assert_not_includes stale, 'app/extensions/permissions/roles/clean.rb'
      end
    end

    test 'the upgrade step holds no vocabulary of its own' do
      # what keeps the yaml and the collections.parameters rewrite from drifting apart, and the stale
      # scan from naming words the cut no longer drops: the filter names come from the migration's
      # map, the model names from asking the app which constants are gone
      source = File.read(DataCycleCore::Engine.root.join('lib', 'rake_helpers', 'concept_filter_upgrade_helper.rb'))

      assert_includes source, 'RenameClassificationFiltersToConceptFilters::FILTER_RENAMES'
      (RenameClassificationFiltersToConceptFilters::FILTER_RENAMES.keys +
       ReplaceClassificationsWithConcepts::LEGACY_TABLES +
       ReplaceClassificationsWithConcepts::RENAMED_TABLES.keys).each do |old|
        assert_not_includes source, "'#{old}'", "the helper spells #{old} itself instead of reading the migration's map"
      end
    end

    # The two tables the scan used to read answer a different question than the code does, in both
    # directions: the dropped names below are not all in them, and the kept ones all match a needle
    # they yield. The kept set is every surviving DataCycleCore::*Classification* constant.
    test 'names dropped constants and keeps quiet about the survivors' do
      dropped = {
        'app/models/dropped_alias.rb' => "DataCycleCore::ClassificationAlias.for_tree('Tags')\n",
        # dropped by a raw DROP TABLE, so it is in neither LEGACY_TABLES nor RENAMED_TABLES
        'app/models/dropped_content.rb' => "DataCycleCore::ClassificationContent.where(thing_id: id)\n",
        'app/models/dropped_collected.rb' => "DataCycleCore::CollectedClassificationContent.count\n"
      }
      kept = {
        'app/jobs/kept_job_caller.rb' => "DataCycleCore::ClassificationMappingJob.perform_later(id, [], [])\n",
        'app/controllers/kept_controller_caller.rb' => "DataCycleCore::ClassificationsController.new\n",
        'app/services/kept_service_caller.rb' => "DataCycleCore::ClassificationService.visible_classification_trees\n",
        'app/jobs/kept_rebuild_caller.rb' => "DataCycleCore::RebuildClassificationMappingsJob.perform_later\n",
        'app/helpers/kept_helper_includer.rb' => "include DataCycleCore::ClassificationHelper\n",
        'app/channels/kept_channel_caller.rb' => "DataCycleCore::ClassificationUpdateChannel.broadcast_to(id)\n"
      }

      in_project do |root|
        dropped.merge(kept).each { |path, content| write(root, path, content) }

        stale = stale_files(root)

        dropped.each_key { |path| assert_includes stale, path }
        kept.each_key { |path| assert_not_includes stale, path }
      end
    end

    test 'reads the file types projects keep this vocabulary in, wherever they keep them' do
      # data-cycle-region-woerthersee is reached by a .rake file and nothing else; before this,
      # config/ was globbed for yml only
      reached = [
        'lib/tasks/project_export.rake',
        'app/views/things/_concept.html.erb',
        'app/views/api/v4/thing.json.jbuilder',
        'config/initializers/concept_defaults.rb'
      ]

      in_project do |root|
        reached.each { |path| write(root, path, "DataCycleCore::ClassificationAlias.first\n") }

        stale = stale_files(root)

        reached.each { |path| assert_includes stale, path }
      end
    end

    test 'names ruby that still calls a dropped model, wherever the project keeps ruby' do
      in_project do |root|
        write(root, 'lib/reports/concept_report.rb', "DataCycleCore::ClassificationAlias.for_tree('Tags')\n")
        write(root, 'db/data_migrate/99999999999999_rename_a_tree.rb', "DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')&.destroy\n")
        write(root, 'app/models/already_moved.rb', "DataCycleCore::Concept.for_tree('Tags')\n")

        stale = stale_files(root)

        assert_includes stale, 'lib/reports/concept_report.rb'
        assert_includes stale, 'db/data_migrate/99999999999999_rename_a_tree.rb'
        assert_not_includes stale, 'app/models/already_moved.rb'
      end
    end

    # The other two halves are about names the code spells out, and an association has neither a
    # `def` nor a constant at its call site. Over the 30 host project branches they named 0 of the
    # 41 files that still called one, so every shape below comes from one of those files.
    test 'names the call shapes a dropped association is written in' do
      dropped = {
        'app/models/called.rb' => "thing.classification_aliases.for_tree('Tags')\n",
        'app/models/symbol_to_proc.rb' => "things.map(&:classification_aliases)\n",
        'app/extensions/declared.rb' => "DataCycleCore::Concept.class_eval { has_many :classification_user_groups }\n",
        'app/models/preloaded.rb' => "DataCycleCore::Thing.includes(:classifications).first\n",
        'app/models/nested_attributes.rb' => "concept.update(classification_polygons_attributes: [{ geom: geom }])\n",
        'app/models/qualified_in_sql.rb' => "DataCycleCore::Thing.where('classifications.id = ?', id)\n",
        # the readers the cut took with the associations, invisible in exactly the same way
        'app/models/reader.rb' => "thing.classification_ids.first\n"
      }

      in_project do |root|
        dropped.each { |path, content| write(root, path, content) }

        stale = stale_files(root)

        dropped.each_key { |path| assert_includes stale, path }
      end
    end

    # The names that survive the cut outnumber the dropped ones in the projects, and all four shapes
    # below sit in files the scan reads: a call on a constant is the constant half's business, a
    # definition is not a call at all, and the other two are names the app still answers to.
    test 'keeps quiet about the calls the cut leaves alone' do
      kept = {
        'app/models/import_categories.rb' => "DataCycleCore::Generic::Common::ImportFunctions.import_classifications(options)\n",
        'app/models/defines_its_own.rb' => "def self.load_root_classifications(item)\n  item\nend\n",
        'app/models/template_property.rb' => "thing.classification_property_names.first\n",
        'config/initializers/data_cycle_core.rb' => "config.excluded_filter_classifications += ['Lift']\n"
      }

      in_project do |root|
        kept.each { |path, content| write(root, path, content) }

        stale = stale_files(root)

        kept.each_key { |path| assert_not_includes stale, path }
      end
    end

    # data-cycle-kw renders this one from a .jb, with no .jbuilder beside it
    test 'reads a jb template the way it reads a jbuilder one' do
      in_project do |root|
        write(root, 'app/views/api/v3/_linked_image.jb', "json.tags thing.classification_aliases.pluck(:name)\n")

        assert_includes stale_files(root), 'app/views/api/v3/_linked_image.jb'
      end
    end

    # The extension this scan reached last: data-cycle-kw and data-cycle-porcia each still called a
    # dropped association from one after merging their port, because no glob here named axlsx
    test 'reads an axlsx template the way it reads a jbuilder one' do
      in_project do |root|
        write(root, 'app/views/contents/members.axlsx', "sheet.add_row [member.classification_aliases.first.name]\n")

        assert_includes stale_files(root), 'app/views/contents/members.axlsx'
      end
    end

    test 'names a migration that has still to run and stays quiet about one that already has' do
      # same body, same dropped constant - only the version differs, so nothing but the applied
      # check can tell the two apart
      applied = ActiveRecord::Base.connection.select_values('SELECT version FROM data_migrations').first

      assert_predicate applied, :present?, 'the test database has no applied data migration to key this on'

      in_project do |root|
        write(root, "db/data_migrate/#{applied}_already_run.rb", "DataCycleCore::Classification.first\n")
        write(root, 'db/data_migrate/99999999999999_still_pending.rb', "DataCycleCore::Classification.first\n")

        stale = stale_files(root)

        assert_includes stale, 'db/data_migrate/99999999999999_still_pending.rb'
        assert_not_includes stale, "db/data_migrate/#{applied}_already_run.rb"
      end
    end

    # The two runs where applied_versions has nothing to ask, in the order the errors below name
    # them: the update_project CI job declares no postgres service, and a project's first container
    # start reaches dc:upgrade before db:create.
    test 'names what it cannot rule out when there is no database to ask' do
      applied = ActiveRecord::Base.connection.select_values('SELECT version FROM data_migrations').first

      [ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError].each do |error|
        in_project do |root|
          write(root, "db/data_migrate/#{applied}_already_run.rb", "DataCycleCore::Classification.first\n")
          write(root, 'app/models/called.rb', "thing.classification_aliases.first\n")

          stale = ActiveRecord::Base.stub(:connection, -> { raise error }) do
            stale_files(root)
          end

          assert_includes stale, 'app/models/called.rb'
          assert_includes stale, "db/data_migrate/#{applied}_already_run.rb"
        end
      end
    end
  end
end
