# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LocaleInheritanceFeatureTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def create_reference(name, translated: false)
      reference = create_content('Artikel', { name: "#{name} DE" })
      return reference unless translated

      I18n.with_locale(:en) do
        reference.set_data_hash(data_hash: { name: "#{name} EN" })
        perform_enqueued_jobs
      end

      reference.reload
    end

    test 'new content inherits the locales of its reference' do
      reference = create_reference('NEW', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      assert_equal [:de, :en], tile.reload.translated_locales
      assert_equal 'NEW DE', tile.name
      assert_equal 'NEW EN', I18n.with_locale(:en) { tile.name }
    end

    test 'a locale added to the reference is handed on to the inheriting content' do
      reference = create_reference('ADDED')
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      assert_equal [:de], tile.reload.translated_locales

      I18n.with_locale(:en) do
        reference.set_data_hash(data_hash: { name: 'ADDED EN' })
        perform_enqueued_jobs
      end

      assert_equal [:de, :en], tile.reload.translated_locales
      assert_equal 'ADDED EN', I18n.with_locale(:en) { tile.name }
    end

    test 'a save in an existing locale of the reference inherits nothing' do
      reference = create_reference('EXISTING', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      assert_no_enqueued_jobs(only: DataCycleCore::LocaleInheritanceJob) do
        I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'EXISTING EN CHANGED' }) }
      end

      assert_equal [:de, :en], tile.reload.translated_locales
    end

    test 'changing the reference inherits the locales of the new one' do
      reference = create_reference('FIRST')
      other_reference = create_reference('SECOND', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      assert_equal [:de], tile.reload.translated_locales

      update_content(tile, { inherited_reference: [other_reference.id] })

      assert_equal [:de, :en], tile.reload.translated_locales
      assert_equal 'SECOND EN', I18n.with_locale(:en) { tile.name }
    end

    test 'the locales of every inheriting property are inherited, blank ones included' do
      reference = create_reference('BLANK')
      secondary = create_reference('SECONDARY', translated: true)
      tile = create_content(
        'Vererbte Sprachen',
        { inherited_reference: [reference.id], secondary_reference: [secondary.id] }
      )

      # :en comes from secondary_reference, which feeds no computed value, so it is created without
      # anything to fill it
      assert_equal [:de, :en], tile.reload.translated_locales
      assert_nil I18n.with_locale(:en) { tile.name }
    end

    test 'the triggering save keeps reporting its own changes' do
      reference = create_reference('CHANGES')
      other_reference = create_reference('CHANGES OTHER', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      tile.set_data_hash(data_hash: { inherited_reference: [other_reference.id], plain_reference: [reference.id] })

      # plain_reference is never part of the inheritance write, so only the caller's own save has it
      assert_includes tile.previous_datahash_changes.keys, 'plain_reference'
      assert_equal [:de, :en], tile.reload.translated_locales
    end

    test 'a locale added to a content nothing inherits from enqueues no job' do
      reference = create_reference('PLAIN')
      create_content('Vererbte Sprachen', { plain_reference: [reference.id] })

      assert_no_enqueued_jobs(only: DataCycleCore::LocaleInheritanceJob) do
        I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'PLAIN EN' }) }
      end
    end

    test 'a content whose template is not translatable inherits nothing' do
      reference = create_reference('UNTRANSLATABLE')
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })
      I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'UNTRANSLATABLE EN' }) }

      writes = 0
      tile.define_singleton_method(:set_data_hash) { |**_kwargs| writes += 1 }

      tile.stub(:translatable?, false) { tile.inherit_missing_locales }

      assert_equal 0, writes
      assert_equal [:de], tile.reload.translated_locales
    end

    test 'the inheritance keeps the version name and the author of the triggering save' do
      user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      reference = create_reference('OPTIONS')
      other_reference = create_reference('OPTIONS OTHER', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      tile.set_data_hash(
        data_hash: { inherited_reference: [other_reference.id] },
        current_user: user,
        version_name: 'probe version'
      )

      reloaded = DataCycleCore::Thing.find(tile.id)

      assert_equal [:de, :en], reloaded.translated_locales
      assert_equal 'probe version', reloaded.version_name
      assert_equal user.id, reloaded.updated_by
    end

    test 'an inherited locale is not reported as a failure, filled or blank' do
      reference = create_reference('QUIET', translated: true)
      secondary = create_reference('QUIET SECONDARY', translated: true)
      logged = []

      filled, blank = Rails.logger.stub(:error, ->(*args) { logged.concat(args) }) do
        [
          create_content('Vererbte Sprachen', { inherited_reference: [reference.id] }),
          # secondary_reference feeds no computed value, so :en is written with nothing to fill it
          create_content('Vererbte Sprachen', { secondary_reference: [secondary.id] })
        ]
      end

      assert_equal [:de, :en], filled.reload.translated_locales
      assert_equal [:de, :en], blank.reload.translated_locales
      assert(logged.none? { |message| message.to_s.include?('could not inherit locale') })
    end

    test 'a write that creates no translation is logged instead of counting as inherited' do
      reference = create_reference('SILENT')
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })
      I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'SILENT EN' }) }

      # DataHash#no_changes reports true without having written anything
      tile.define_singleton_method(:set_data_hash) { |**_kwargs| true }

      logged = []
      Rails.logger.stub(:error, ->(*args) { logged.concat(args) }) { tile.inherit_missing_locales }

      assert_equal [:de], tile.reload.translated_locales
      assert(logged.any? { |message| message.to_s.include?('could not inherit locale :en') })
    end

    test 'an embedded content is not reached by the inheritance' do
      reference = create_reference('EMBEDDED')
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })
      I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'EMBEDDED EN' }) }
      tile.update_column(:content_type, 'embedded')

      # the job path loads no embedded content, and the shared guard skips one reaching it anyway
      assert_empty DataCycleCore::Feature::LocaleInheritance.inheriting_things(reference).ids

      tile.reload.inherit_missing_locales

      assert_equal [:de], tile.reload.translated_locales
    end

    test 'the inheritance writes do not repeat the report of the triggering save' do
      reference = create_reference('REPORT')
      other_reference = create_reference('REPORT OTHER', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      reports = 0
      tile.define_singleton_method(:execute_update_webhooks) { |**| reports += 1 }

      tile.set_data_hash(data_hash: { inherited_reference: [other_reference.id] })

      assert_equal [:de, :en], tile.reload.translated_locales
      assert_equal 1, reports
    end

    test 'a write with no triggering save reports itself' do
      reference = create_reference('SELF REPORT')
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })
      I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'SELF REPORT EN' }) }

      reports = 0
      tile.reload.define_singleton_method(:execute_update_webhooks) { |**| reports += 1 }

      tile.inherit_missing_locales

      assert_equal [:de, :en], tile.reload.translated_locales
      assert_equal 1, reports
    end

    test 'a nested write that raises is logged and leaves the triggering save alone' do
      reference = create_reference('RAISING')
      other_reference = create_reference('RAISING OTHER', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      tile.define_singleton_method(:set_data_hash) do |**kwargs|
        raise ActiveRecord::RecordNotUnique, 'probe' if @inheriting_locales

        super(**kwargs)
      end

      logged = []
      Rails.logger.stub(:error, ->(*args) { logged.concat(args) }) do
        tile.set_data_hash_with_translations(data_hash: { inherited_reference: [other_reference.id] })
      end

      # the write runs inside the transaction of set_data_hash_with_translations
      assert_equal [other_reference.id], tile.reload.inherited_reference.map(&:id)
      assert_equal [:de], tile.translated_locales
      assert(logged.any? { |message| message.to_s.include?('could not inherit locale :en') })
    end

    test 'a nested write that aborts the transaction leaves the triggering save alone' do
      reference = create_reference('ABORTING')
      other_reference = create_reference('ABORTING OTHER', translated: true)
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })

      # aborts the connection from before_save_data_hash, which runs before set_data_hash opens its
      # own transaction: only a savepoint around the whole write gets it back for the enqueue check
      tile.define_singleton_method(:before_save_data_hash) do |options|
        DataCycleCore::Thing.connection.execute('SELECT 1 / 0') if @inheriting_locales

        super(options)
      end

      logged = []
      Rails.logger.stub(:error, ->(*args) { logged.concat(args) }) do
        tile.set_data_hash_with_translations(data_hash: { inherited_reference: [other_reference.id] })
      end

      assert_equal [other_reference.id], tile.reload.inherited_reference.map(&:id)
      assert_equal [:de], tile.translated_locales
      assert(logged.any? { |message| message.to_s.include?('could not inherit locale :en') })
    end

    test 'a locale that cannot be written does not report as the outcome of the triggering save' do
      reference = create_reference('FAILING')
      tile = create_content('Vererbte Sprachen', { inherited_reference: [reference.id] })
      I18n.with_locale(:en) { reference.set_data_hash(data_hash: { name: 'FAILING EN' }) }

      tile.define_singleton_method(:set_data_hash) do |**_kwargs|
        warnings.add(:base, 'inheriting warning')
        errors.add(:base, 'inheriting error')
        false
      end

      I18n.with_locale(:de) { tile.warnings.add(:base, 'caller warning') }
      tile.inherit_missing_locales

      assert_empty tile.i18n_warnings.keys - ['de']
      assert_includes I18n.with_locale(:de) { tile.warnings.full_messages }, 'caller warning'
      assert_predicate tile, :i18n_valid?
    end
  end
end
