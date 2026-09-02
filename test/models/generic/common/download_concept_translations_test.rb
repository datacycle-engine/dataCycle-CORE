# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DownloadConceptTranslationsTest < ActiveSupport::TestCase
    STRATEGY = DataCycleCore::Generic::Common::DownloadConceptTranslations

    def fixture_file
      File.expand_path('../../../fixtures/files/concept_translations.csv', __dir__)
    end

    # --- translate_concept -------------------------------------------------

    test 'translate_concept overrides the name with the translation for the matched key' do
      concept = { 'id' => 'funitel', 'name' => 'funitel', 'parent_id' => 'lift', 'tree_label' => 'Lifttypen' }
      translated = STRATEGY.translate_concept(concept, { 'funitel' => 'Funitel' }, 'id')

      assert_equal 'Funitel', translated['name']
      # all other base attributes are preserved
      assert_equal 'lift', translated['parent_id']
      assert_equal 'Lifttypen', translated['tree_label']
      assert_equal 'funitel', translated['id']
    end

    test 'translate_concept keeps the original name when no translation is found' do
      concept = { 'id' => 'unknown', 'name' => 'original' }
      translated = STRATEGY.translate_concept(concept, { 'funitel' => 'Funitel' }, 'id')

      assert_equal 'original', translated['name']
    end

    test 'translate_concept keeps the original name for a blank translation' do
      concept = { 'id' => 'funitel', 'name' => 'original' }
      translated = STRATEGY.translate_concept(concept, { 'funitel' => '' }, 'id')

      assert_equal 'original', translated['name']
    end

    test 'translate_concept drops external_system and dc_external_id' do
      concept = { 'id' => 'funitel', 'name' => 'funitel', 'external_system' => { 'credential_keys' => ['a'] }, 'dc_external_id' => 'x' }
      translated = STRATEGY.translate_concept(concept, {}, 'id')

      assert_not translated.key?('external_system')
      assert_not translated.key?('dc_external_id')
    end

    test 'translate_concept matches nested key paths' do
      concept = { 'id' => 'funitel', 'name' => 'funitel', 'value' => { 'code' => 'FUN' } }
      translated = STRATEGY.translate_concept(concept, { 'FUN' => 'Funitel' }, 'value.code')

      assert_equal 'Funitel', translated['name']
    end

    # --- load_translations -------------------------------------------------

    test 'load_translations reads the column matching the locale header' do
      options = { download: { file: fixture_file } }

      de = STRATEGY.load_translations(options:, locale: :de)

      assert_equal({ 'funitel' => 'Funitel', 'chairlift' => 'Sessellift', 'onlyde' => 'NurDeutsch' }, de)

      en = STRATEGY.load_translations(options:, locale: :en)
      # blank key row and the row with a blank en value are skipped
      assert_equal({ 'funitel' => 'funitel', 'chairlift' => 'chair lift' }, en)
    end

    test 'load_translations honours an explicit translation_locale_column' do
      options = { download: { file: fixture_file, translation_locale_column: 2 } }

      # column index 2 is the english column regardless of the requested locale
      assert_equal({ 'funitel' => 'funitel', 'chairlift' => 'chair lift' }, STRATEGY.load_translations(options:, locale: :de))
    end

    test 'load_translations treats the first row as data when headers is false' do
      options = { download: { file: fixture_file, headers: false } }

      # header row becomes data, value column defaults to key_column + 1 (the "de" column)
      translations = STRATEGY.load_translations(options:, locale: :en)

      assert_equal 'de', translations['id']
      assert_equal 'Funitel', translations['funitel']
    end

    test 'load_translations raises without a file' do
      assert_raises(ArgumentError) { STRATEGY.load_translations(options: { download: {} }, locale: :de) }
    end

    # --- file_paths --------------------------------------------------------

    test 'file_paths renders the locale via ERB' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'trans_de.csv'), 'id;de')
        File.write(File.join(dir, 'trans_en.csv'), 'id;en')

        paths = STRATEGY.file_paths(File.join(dir, 'trans_<%= locale %>.csv'), :en)

        assert_equal [File.join(dir, 'trans_en.csv')], paths
      end
    end

    test 'file_paths accepts multiple file globs' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'a.csv'), 'x')
        File.write(File.join(dir, 'b.csv'), 'x')

        paths = STRATEGY.file_paths([File.join(dir, 'a.csv'), File.join(dir, 'b.csv')], :de)

        assert_equal [File.join(dir, 'a.csv'), File.join(dir, 'b.csv')], paths.sort
      end
    end

    # --- base_match --------------------------------------------------------

    test 'base_match pins the existence filter to the base locale' do
      match = STRATEGY.base_match(options: { download: {} }, base_locale: 'de')

      assert_equal({ 'dump.de' => { '$exists' => true }, 'dump.de.deleted_at' => { '$exists' => false } }, match)
    end

    test 'base_match merges an optional source_filter' do
      match = STRATEGY.base_match(options: { download: { source_filter: { 'foo' => 'bar' } } }, base_locale: 'en')

      assert_equal({ '$exists' => true }, match['dump.en'])
      assert_equal 'bar', match['foo']
    end

    # --- load_translated_concepts ------------------------------------------

    test 'load_translated_concepts raises without a read_type' do
      assert_raises(ArgumentError) do
        STRATEGY.load_translated_concepts(options: { download: { file: fixture_file } }, locale: :de)
      end
    end
  end
end
