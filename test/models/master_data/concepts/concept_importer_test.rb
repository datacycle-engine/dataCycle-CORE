# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

module DataCycleCore
  # Unit coverage for the ConceptImporter parsing/merging helpers and the error
  # capture paths. The importer is built with both import flags disabled so the
  # constructor performs no IO, letting the pure transformation helpers be driven
  # directly; the DB-touching insert rescues are exercised through stubs.
  class ConceptImporterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    def build
      DataCycleCore::MasterData::Concepts::ConceptImporter.new(import_concepts: false, import_mappings: false)
    end

    # --- render_errors ----------------------------------------------------------------

    test 'render_errors is a no-op without errors and prints the collected errors otherwise' do
      importer = build

      assert_nil importer.render_errors

      importer.instance_variable_set(:@errors, ['something broke'])

      assert_output(/errors were encountered during import/) { importer.render_errors }
    end

    # --- append_concept_mappings! -----------------------------------------------------

    test 'append_concept_mappings! concatenates array and string values across files' do
      importer = build
      importer.send(:append_concept_mappings!, { 'a' => ['x'], 'b' => 'one' })
      importer.send(:append_concept_mappings!, { 'a' => ['y'], 'b' => 'two' })
      mappings = importer.instance_variable_get(:@concept_mappings)

      assert_equal ['x', 'y'], mappings['a']
      assert_equal ['one', 'two'], mappings['b']
    end

    # --- YAML loading error capture ---------------------------------------------------

    test 'load_*_from_path capture and record YAML parse errors per file' do
      importer = build

      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'classifications.yml'), "- [unterminated\n")
        File.write(File.join(dir, 'classification_mappings.yml'), "a: [unterminated\n")

        importer.send(:load_concepts_from_path, dir)
        importer.send(:load_concept_mappings_from_path, dir)
      end

      assert(importer.errors.any? { |e| e.include?('error loading YML File') })
      assert(importer.errors.any? { |e| e.include?('error loading mappings YML File') })
    end

    # --- append_concept_schemes! (merge + deduplicate) --------------------------------

    test 'append_concept_schemes! merges and deduplicates Inhaltstypen across files' do
      importer = build
      importer.send(:append_concept_schemes!, [{ 'Inhaltstypen' => ['Artikel', 'Bild'] }])
      importer.send(:append_concept_schemes!, [{ 'Inhaltstypen' => ['Bild', 'Video'] }])
      concepts = importer.instance_variable_get(:@concept_schemes)['Inhaltstypen'][:concepts]

      assert_equal ['Artikel', 'Bild', 'Video'], concepts.pluck(:name)
    end

    # --- parse_concept_scheme (modern hash form) --------------------------------------

    test 'parse_concept_scheme parses a modern hash scheme with nested, i18n and described concepts' do
      importer = build
      scheme = importer.send(:parse_concept_scheme, {
        'name' => 'Tags',
        'external_key' => 'tags-key',
        'concepts' => [
          { 'name' => 'Plain', 'concepts' => [{ 'name' => 'Child' }] },
          { 'name' => { 'de' => 'Deutsch', 'en' => 'English' } },
          { 'name' => 'WithDesc', 'description' => { 'de' => 'eine Beschreibung' } }
        ]
      })

      assert_equal 'Tags', scheme[:name]
      assert_equal 'tags-key', scheme[:external_key]

      concepts = scheme[:concepts]

      assert_equal 'Tags > Plain', concepts.find { |c| c[:name] == 'Plain' }[:external_key]
      assert(concepts.any? { |c| c[:external_key] == 'Tags > Plain > Child' }) # nested recursion

      i18n = concepts.find { |c| c[:name_i18n].present? }

      assert_equal({ de: 'Deutsch', en: 'English' }, i18n[:name_i18n])
      assert_equal 'Tags > Deutsch', i18n[:external_key] # external key derived from the first available locale

      described = concepts.find { |c| c[:description_i18n].present? }

      assert_equal({ de: 'eine Beschreibung' }, described[:description_i18n])
    end

    # --- parse_concept_scheme (legacy form) -------------------------------------------

    test 'parse_concept_scheme parses a legacy scheme including the $$ internal prefix' do
      importer = build
      scheme = importer.send(:parse_concept_scheme, { '$$Hidden | public, internal' => ['ConceptA'] })

      assert_equal 'Hidden', scheme[:name]
      assert scheme[:internal]
      assert_equal ['public', 'internal'], scheme[:visibility]
      assert_equal 'Hidden', scheme[:external_key]
    end

    # --- insert rescues (DB stubbed to fail) ------------------------------------------

    test 'insert_concept_schemes records an error when the insert fails' do
      importer = build
      importer.instance_variable_set(:@concept_schemes, { 'X' => { name: 'X', external_key: 'x' } })

      DataCycleCore::ClassificationTreeLabel.stub(:with_deleted, ->(*_a, **_k) { raise 'db unavailable' }) do
        importer.send(:insert_concept_schemes)
      end

      assert(importer.errors.any? { |e| e.include?('error inserting concept_schemes') })
    end

    test 'insert_concepts records a per-scheme error when the classification insert fails' do
      importer = build
      importer.instance_variable_set(:@concept_schemes, {
        'X' => { name: 'X', external_source_id: 7, concepts: [{ external_key: 'k', name: 'K' }] }
      })

      fake_scheme = Object.new
      fake_scheme.define_singleton_method(:blank?) { false }
      fake_scheme.define_singleton_method(:external_source_id) { 7 }
      fake_scheme.define_singleton_method(:insert_all_external_classifications) { |_concepts| raise 'insert failed' }

      relation = Object.new
      relation.define_singleton_method(:index_by) { |&_block| { 'X' => fake_scheme } }

      DataCycleCore::ClassificationTreeLabel.stub(:where, ->(*_a, **_k) { relation }) do
        importer.send(:insert_concepts)
      end

      assert(importer.errors.any? { |e| e.include?('error inserting concepts for X') })
    end
  end
end
