# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportTagsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyUtilityObject = Struct.new(:external_source, :options)

    class FakeMongoAggregation
      def initialize
        @steps = []
      end

      ['where', 'unwind', 'project', 'group'].each do |operator|
        define_method(operator) do |argument|
          @steps << { "$#{operator == 'where' ? 'match' : operator}" => argument }
          self
        end
      end

      def pipeline
        @steps
      end

      def collection
        self
      end

      def aggregate(pipeline)
        pipeline
      end
    end

    before(:all) do
      @subject = DataCycleCore::Generic::Common::ImportTags
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @utility_object = DummyUtilityObject.new(@local_system, {})
    end

    test 'import_data raises for missing configuration attributes' do
      error = assert_raises(RuntimeError) { @subject.import_data(utility_object: @utility_object, options: { import: {} }) }
      assert_match('tree_label', error.message)

      error = assert_raises(RuntimeError) { @subject.import_data(utility_object: @utility_object, options: { import: { tree_label: 'Tags' } }) }
      assert_match('tag_id_path', error.message)

      error = assert_raises(RuntimeError) { @subject.import_data(utility_object: @utility_object, options: { import: { tree_label: 'Tags', tag_id_path: 'id' } }) }
      assert_match('tag_name_path', error.message)
    end

    test 'extract_data builds external_key with prefix and supports descriptions and uris' do
      options = { import: { external_id_prefix: 'TAG - ' } }
      raw_data = { 'id' => 't1', 'tag' => 'Tag One', 'desc' => 'Description', 'uri' => 'https://uri.test/t1' }

      assert_equal(
        { external_key: 'TAG - t1', name: 'Tag One', description: 'Description', uri: 'https://uri.test/t1' },
        @subject.extract_data(options, raw_data)
      )
      assert_equal({ external_key: 'TAG - t2', name: 'Tag Two' }, @subject.extract_data(options, { 'id' => 't2', 'tag' => 'Tag Two' }))
    end

    test 'extract_data supports hashed and rounded external ids' do
      assert_equal(
        { external_key: Digest::MD5.new.update('t1').hexdigest, name: 'Tag' },
        @subject.extract_data({ import: { external_id_hash_method: 'MD5' } }, { 'id' => 't1', 'tag' => 'Tag' })
      )
      assert_equal(
        { external_key: '5', name: 'Tag' },
        @subject.extract_data({ import: { external_id_hash_method: 'round' } }, { 'id' => '4.6', 'tag' => 'Tag' })
      )
    end

    test 'extract_data joins array tags, rounds names and falls back to unknown' do
      assert_equal('One, Two', @subject.extract_data({ import: {} }, { 'id' => 't1', 'tag' => ['One', 'Two'] })[:name])
      assert_equal(4, @subject.extract_data({ import: { tag_name_function: 'round' } }, { 'id' => 't1', 'tag' => '4.4' })[:name])
      assert_equal('unknown', @subject.extract_data({ import: {} }, { 'id' => 't1' })[:name])
    end

    test 'parse_common_tag_path prefers tag_path and computes common prefix otherwise' do
      assert_equal('tags', @subject.parse_common_tag_path({ import: { tag_path: 'tags', tag_id_path: 'a.id', tag_name_path: 'b.name' } }))
      assert_equal(['tags'], @subject.parse_common_tag_path({ import: { tag_id_path: 'tags.id', tag_name_path: 'tags.name' } }))
      assert_empty(@subject.parse_common_tag_path({ import: { tag_id_path: 'ids.id', tag_name_path: 'names.name' } }))
    end

    test 'unwind_project_data uses full paths when no common path exists' do
      raw_data = { 'id' => 't1', 'name' => 'Tag One', 'desc' => 'D', 'uri' => 'U' }
      result = @subject.unwind_project_data(raw_data, [], ['id'], ['name'], ['desc'], ['uri'])

      assert_equal([{ 'id' => 't1', 'tag' => 'Tag One', 'desc' => 'D', 'uri' => 'U' }], result)
    end

    test 'unwind_project_data returns nil for blank data at common path' do
      assert_nil(@subject.unwind_project_data({ 'other' => 'x' }, ['tags'], ['tags', 'id'], ['tags', 'name']))
    end

    test 'unwind_project_data unwinds arrays with relative paths' do
      raw_data = { 'tags' => [{ 'id' => 't1', 'name' => 'One', 'desc' => 'D1', 'uri' => 'U1' }, { 'id' => 't2', 'name' => 'Two', 'desc' => 'D2', 'uri' => 'U2' }] }
      result = @subject.unwind_project_data(raw_data, ['tags'], ['tags', 'id'], ['tags', 'name'], ['tags', 'desc'], ['tags', 'uri'])

      assert_equal(
        [
          { 'id' => 't1', 'tag' => 'One', 'desc' => 'D1', 'uri' => 'U1' },
          { 'id' => 't2', 'tag' => 'Two', 'desc' => 'D2', 'uri' => 'U2' }
        ],
        result
      )
    end

    test 'unwind_project_data uses array items directly for scalar arrays' do
      result = @subject.unwind_project_data({ 'tags' => ['One', 'Two'] }, ['tags'], ['tags'], ['tags'])

      assert_equal([{ 'id' => 'One', 'tag' => 'One' }, { 'id' => 'Two', 'tag' => 'Two' }], result)
    end

    test 'unwind_project_data digs full paths for non array data' do
      raw_data = { 'tags' => { 'id' => 't1', 'name' => 'One' } }
      result = @subject.unwind_project_data(raw_data, ['tags'], ['tags', 'id'], ['tags', 'name'])

      assert_equal([{ 'id' => 't1', 'tag' => 'One' }], result)
    end

    test 'process_content imports tags as classifications' do
      options = { import: { tree_label: 'IT Tag Tree', tag_id_path: 'tags.id', tag_name_path: 'tags.name', external_id_prefix: 'IT - ', locales: [:de] } }
      raw_data = { 'tags' => [{ 'id' => 't1', 'name' => 'Tag One' }, { 'id' => 't2', 'name' => 'Tag Two' }] }

      @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:)

      alias_one = DataCycleCore::ClassificationAlias.find_by(external_key: 'IT - t1', external_source_id: @local_system.id)

      assert_not_nil(alias_one)
      assert_equal('Tag One', alias_one.name)
      assert_equal(2, DataCycleCore::Concept.for_tree('IT Tag Tree').count)
      assert_equal(['Tag One', 'Tag Two'], DataCycleCore::Concept.for_tree('IT Tag Tree').pluck(:internal_name).sort)
    end

    test 'process_content returns nil for blank options, foreign locales or missing keywords' do
      options = { import: { tree_label: 'IT Empty Tree', tag_id_path: 'tags.id', tag_name_path: 'tags.name', locales: [:de] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'tags' => [] }, locale: :de, options: {}))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'tags' => [{ 'id' => 't1', 'name' => 'X' }] }, locale: :en, options:))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'other' => 'x' }, locale: :de, options:))
      assert_equal(0, DataCycleCore::Concept.for_tree('IT Empty Tree').count)
    end

    test 'load_root_classifications builds the aggregation pipeline' do
      options = {
        import: {
          tag_id_path: 'tags.id',
          tag_name_path: 'tags.name',
          tag_description_path: 'tags.desc',
          tag_uri_path: 'tags.uri',
          source_filter: { 'dump.de.type' => 'tag' }
        }
      }
      result = @subject.load_root_classifications(FakeMongoAggregation.new, 'de', options)

      assert_equal({ '$match' => { 'dump.de.tags.id' => { '$ne' => nil }, 'dump.de.type' => 'tag' } }, result.first)
      assert_equal([{ '$unwind' => 'dump' }, { '$unwind' => 'dump.de' }, { '$unwind' => 'dump.de.tags' }], result[1..3])
      assert_equal({ '$match' => { 'dump.de.type' => 'tag' } }, result[4])
      assert_equal(
        {
          '$project' => {
            'dump.de.id': '$dump.de.tags.id',
            'dump.de.tag': '$dump.de.tags.name',
            'dump.de.desc' => '$dump.de.tags.desc',
            'dump.de.uri' => '$dump.de.tags.uri'
          }
        },
        result[5]
      )
      assert(result[6].key?('$group'))
      assert_equal({ '$match' => { '_id' => { '$ne' => nil } } }, result.last)
    end
  end
end
