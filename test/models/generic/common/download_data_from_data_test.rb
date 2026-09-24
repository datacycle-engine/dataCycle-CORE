# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DownloadDataFromDataTest < ActiveSupport::TestCase
    test 'data_id_path is nil' do
      options = {
        download: {
          data_id_path: nil,
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal '', paths['data_id_path']
        assert_equal "dump.#{locale}.dataPath", paths['full_id_path']
      end
    end

    test 'data_id_path key is not defined --> fallback to "id"' do
      options = {
        download: {
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal 'id', paths['data_id_path']
        assert_equal "dump.#{locale}.dataPath.id", paths['full_id_path']
      end
    end

    test 'data_name_path is nil' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: nil,
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal '', paths['data_name_path']
      end
    end

    test 'data_name_path key is not defined --> fallback to data_id_path' do
      options = {
        download: {
          data_id_path: 'id',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal options[:download][:data_id_path], paths['data_name_path']
      end
    end

    test 'data_path is nil' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: nil
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal '', paths['data_path']
        assert_equal "dump.#{locale}", paths['full_data_path']
      end
    end

    test 'data_path key is not defined' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal '', paths['data_path']
        assert_equal "dump.#{locale}", paths['full_data_path']
      end
    end

    test 'data_name_path and additional_data_paths have erb evaluations' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: '<%= "name.#{locale}" %>', # rubocop:disable Lint/InterpolationCheck
          data_path: 'dataPath',
          data_name_path_fallback: [
            '<%= "name_#{locale}" %>' # rubocop:disable Lint/InterpolationCheck
          ]
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal "name.#{locale}", paths['data_name_path']
        assert_equal ["name_#{locale}"], paths['data_name_path_fallback']
      end
    end

    test 'array postions in data_path are correctly identified 1' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[].arr[].obj.name'
        }
      }
      locale = :de
      paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

      assert_equal [1, 1, 0, 1], paths['path_array_positions']
    end

    test 'array postions in data_path are correctly identified 2' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath.obj.name'
        }
      }
      locale = :de
      paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

      assert_equal [0, 0, 1], paths['path_array_positions']
    end

    test 'additional_data_paths (array) are correctly processed' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          additional_data_paths: [
            { name: 'attr1', path: 'path1' },
            { name: 'attr2', path: 'path2' }
          ]
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)
        exp = {
          'attr1' => "$dump.#{locale}.path1",
          'attr2' => "$dump.#{locale}.path2"
        }

        assert_equal exp, paths['additional_paths']
      end
    end

    test 'additional_data_paths (hash) are correctly processed' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          additional_data_paths: {
            attr1: 'path1',
            attr2: 'path2'
          }
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)
        exp = {
          'attr1' => "$dump.#{locale}.path1",
          'attr2' => "$dump.#{locale}.path2"
        }

        assert_equal exp, paths['additional_paths']
      end
    end

    test 'additional_data_paths are not present' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal({}, paths['additional_paths'])
      end
    end

    test 'additional_data_paths are empty' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          additional_data_paths: []
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_equal({}, paths['additional_paths'])
      end
    end

    test 'data_path starting with dump.<locale> is not prefixed again' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dump.de.dataPath[].obj'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)

        assert_nil paths['data_path_prefix']
        assert_equal 'dump.de.dataPath.obj', paths['data_path']
        assert_equal 'dump.de.dataPath.obj', paths['full_data_path']
        assert_equal 'dump.de.dataPath.obj.id', paths['full_id_path']
        assert_equal [0, 0, 1, 1], paths['path_array_positions']
      end
    end

    test 'data_path consisting only of dump.<locale> is not prefixed again' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dump.de'
        }
      }
      paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale: 'en')

      assert_nil paths['data_path_prefix']
      assert_equal 'dump.de', paths['full_data_path']
      assert_equal 'dump.de.id', paths['full_id_path']
    end

    test 'data_path not starting with dump.<locale> is still prefixed' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dump'
        }
      }
      paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale: 'en')

      assert_equal 'dump.en', paths['data_path_prefix']
      assert_equal 'dump.en.dump', paths['full_data_path']
    end

    test 'additional_data_paths starting with dump.<locale> are not prefixed again' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          additional_data_paths: {
            attr1: 'dump.de.path1',
            attr2: 'path2'
          }
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options:, locale:)
        exp = {
          'attr1' => '$dump.de.path1',
          'attr2' => "$dump.#{locale}.path2"
        }

        assert_equal exp, paths['additional_paths']
      end
    end

    test 'bulk_mark_deleted_options reset read collection options to target collection structure' do
      last_download = Time.zone.local(2026, 6, 1)
      options = {
        download: {
          name: 'ccauthors',
          source_type: 'ccauthors',
          read_type: ['accommodations', 'infrastructure_items', 'events'],
          data_path: 'CCAuthor',
          data_id_path: 'Id',
          data_name_path: 'Names.Translation.text',
          data_id_prefix: 'prefix_',
          data_id_transformation: 'md5',
          additional_data_paths: { data_owner: 'Details.DataOwner.text' },
          attribute_whitelist: ['attr1'],
          source_filter: { 'dump.de.CCAuthor.Type' => 'type' },
          bulk_mark_deleted: true
        }
      }
      delete_options = DataCycleCore::Generic::Common::DownloadDataFromData.bulk_mark_deleted_options(options:, last_download:)

      assert_equal 'delete_ccauthors', delete_options.dig(:download, :name)
      assert_nil delete_options.dig(:download, :read_type)
      assert_equal({ 'seen_at' => { '$lt' => last_download } }, delete_options.dig(:download, :source_filter))
      # ids are loaded from dump.<locale>.id of the target collection, where the prefix is already applied
      paths = DataCycleCore::Generic::Common::DownloadDataFromData.prepare_data_paths(options: delete_options, locale: 'de')

      assert_equal 'dump.de.id', paths['full_id_path']
      assert_equal({}, paths['additional_paths'])
      assert_nil delete_options.dig(:download, :data_id_prefix)
      assert_nil delete_options.dig(:download, :attribute_whitelist)
      # the transformation maps dump.<locale>.id to external_id and has to be kept
      assert_equal 'md5', delete_options.dig(:download, :data_id_transformation)
      # original options stay untouched
      assert_equal ['accommodations', 'infrastructure_items', 'events'], options.dig(:download, :read_type)
      assert_equal({ 'dump.de.CCAuthor.Type' => 'type' }, options.dig(:download, :source_filter))
    end

    # from here test the piplelines
    test 'attribute_whitelist is present' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          attribute_whitelist: ['attr1', 'attr2'],
          additional_data_paths: [
            { name: 'attr1', path: 'path1' },
            { name: 'attr2', path: 'path2' }
          ]
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = { '$project' => { 'id' => 1, 'name' => 1, 'attr1' => 1, 'attr2' => 1 } }
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$project') }

      assert_equal exp, relevant_pipeline
    end

    test 'attribute_blacklist is present' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          attribute_blacklist: ['attr1', 'attr2']
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = { '$project' => { 'attr1' => 0, 'attr2' => 0 } }
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$project') }

      assert_equal exp, relevant_pipeline
    end

    test 'attribute_blacklist and attribute_whitelist are present' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          attribute_whitelist: ['attr1', 'attr2'],
          attribute_blacklist: ['attr1']
        }
      }
      locale = :de
      assert_raise(ArgumentError) do
        DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      end
    end

    test 'trim_name option set to true by default' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = { '$addFields' => { 'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } } } }
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$addFields') }

      assert_equal exp, relevant_pipeline
    end

    test 'trim_name option set to false' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          trim_name: false
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$addFields') }

      assert_nil relevant_pipeline&.dig('$addFields', 'name', '$trim')
    end

    test 'data_id_prefix is correctly added to id' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          data_id_prefix: 'prefix_'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = { '$addFields' => { 'id' => { '$concat' => [options.dig(:download, :data_id_prefix), { '$toString' => '$id' }] } } }

      assert_equal exp, pipelines[-2]
    end

    test 'assures that data with nil id are filtered out' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = { '$match' => { 'id' => { '$nin' => [nil, ''] } } }

      assert_equal exp, pipelines.last
    end

    test 'dynamic projection, match & unwind stages are correctly created 1' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[].arr[].obj'
        }
      }
      ['en', 'de'].each do |locale|
        source_filter = { "dump.#{locale}.dataPath.arr.obj.type" => 'type' }
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)
        exp = [
          { '$project' => { 'data' => "$dump.#{locale}.dataPath", 'add_data' => nil, 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.arr.obj.id' => { '$exists' => true }, 'data.arr.obj.type' => 'type' } },
          { '$project' => { 'data' => '$data.arr', 'add_data' => '$add_data', 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.obj.id' => { '$exists' => true }, 'data.obj.type' => 'type' } },
          { '$project' => { 'data' => '$data.obj', 'add_data' => '$add_data', 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.id' => { '$exists' => true }, 'data.type' => 'type' } }
        ]
        first_index = pipelines.find_index { |p| p.key?('$project') } # first projection stage
        last_index = pipelines.rindex { |p| p.key?('$unwind') } # last unwind stage

        assert_equal exp, pipelines[first_index..(last_index + 1)]
      end
    end

    test 'dynamic projection, match & unwind stages are correctly created 2' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath.obj'
        }
      }
      ['en', 'de'].each do |locale|
        source_filter = { "dump.#{locale}.dataPath.obj.type" => 'type' }
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)
        exp = [
          { '$project' => { 'data' => "$dump.#{locale}.dataPath", 'add_data' => nil, 'external_system' => 1 } },
          { '$project' => { 'data' => '$data.obj', 'add_data' => '$add_data', 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.id' => { '$exists' => true }, 'data.type' => 'type' } }
        ]
        first_index = pipelines.find_index { |p| p.key?('$project') } # first projection stage
        last_index = pipelines.rindex { |p| p.key?('$unwind') } # last unwind stage

        assert_equal exp, pipelines[first_index..(last_index + 1)]
      end
    end

    test 'test complex pipeline 1' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[].arr[].obj'
        }
      }
      ['en', 'de'].each do |locale|
        source_filter = { "dump.#{locale}.dataPath.arr.obj.type" => 'type' }
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: source_filter)
        exp = [
          { '$match' => { "dump.#{locale}.dataPath.arr.obj.id" => { '$exists' => true }, "dump.#{locale}.dataPath.arr.obj.type" => 'type' } },
          { '$project' => { 'data' => "$dump.#{locale}.dataPath", 'add_data' => nil, 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.arr.obj.id' => { '$exists' => true }, 'data.arr.obj.type' => 'type' } },
          { '$project' => { 'data' => '$data.arr', 'add_data' => '$add_data', 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.obj.id' => { '$exists' => true }, 'data.obj.type' => 'type' } },
          { '$project' => { 'data' => '$data.obj', 'add_data' => '$add_data', 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.id' => { '$exists' => true }, 'data.type' => 'type' } },
          { '$addFields' =>
            { 'data.id' => { '$ifNull' => ['$data.id', '$data.name'] },
              'data.name' => '$data.name' } },
          { '$group' => { '_id' => '$data.id', 'data' => { '$first' => '$data' }, 'external_system' => { '$mergeObjects' => '$external_system' } } },
          { '$addFields' => { 'data.external_system' => '$external_system' } },
          { '$replaceRoot' => { 'newRoot' => '$data' } },
          { '$addFields' => { 'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } } } },
          { '$match' => { 'id' => { '$nin' => [nil, ''] } } }
        ]

        assert_equal exp, pipelines
      end
    end

    test 'test complex pipeline 2' do
      options = {
        download: {
          data_id_path: nil,
          data_name_path: nil,
          data_path: 'dataPath[].author'
        }
      }
      ['en', 'de'].each do |locale|
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
        exp = [
          { '$match' => { "dump.#{locale}.dataPath.author" => { '$exists' => true } } },
          { '$project' => { 'data' => "$dump.#{locale}.dataPath", 'add_data' => nil, 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.author' => { '$exists' => true } } },
          { '$project' => { 'data' => '$data.author', 'add_data' => '$add_data', 'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data' => { '$exists' => true } } },
          { '$addFields' => { 'data.id' => '$data', 'data.name' => '$data' } },
          { '$group' => { '_id' => '$data.id', 'data' => { '$first' => '$data' }, 'external_system' => { '$mergeObjects' => '$external_system' } } },
          { '$addFields' => { 'data.external_system' => '$external_system' } },
          { '$replaceRoot' => { 'newRoot' => '$data' } },
          { '$addFields' => { 'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } } } },
          { '$match' => { 'id' => { '$nin' => [nil, ''] } } }
        ]

        assert_equal exp, pipelines
      end
    end

    test 'test complex pipeline 3' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          additional_data_paths: [
            { name: 'attr1', path: 'path1' }
          ],
          attribute_whitelist: ['attr1', 'attr2']
        }
      }
      ['en', 'de'].each do |locale|
        source_filter = { "dump.#{locale}.dataPath.type" => 'type' }
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)
        exp = [
          { '$match' => { "dump.#{locale}.dataPath.id" => { '$exists' => true }, "dump.#{locale}.dataPath.type" => 'type' } },
          { '$project' =>
            { 'data' => "$dump.#{locale}.dataPath",
              'add_data' => { 'attr1' => "$dump.#{locale}.path1" },
              'external_system' => 1 } },
          { '$unwind' => '$data' },
          { '$match' => { 'data.id' => { '$exists' => true }, 'data.type' => 'type' } },
          { '$addFields' =>
            { 'data.id' => { '$ifNull' => ['$data.id', '$data.name'] },
              'data.name' => '$data.name',
              'data.attr1' => { '$ifNull' => ['$data.attr1', '$add_data.attr1'] } } },
          { '$group' => { '_id' => '$data.id', 'data' => { '$first' => '$data' }, 'external_system' => { '$mergeObjects' => '$external_system' } } },
          { '$addFields' => { 'data.external_system' => '$external_system' } },
          { '$replaceRoot' => { 'newRoot' => '$data' } },
          { '$addFields' => { 'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } } } },
          { '$project' => { 'attr1' => 1, 'attr2' => 1, 'id' => 1, 'name' => 1 } },
          { '$match' => { 'id' => { '$nin' => [nil, ''] } } }
        ]

        assert_equal exp, pipelines
      end
    end

    test 'test complex pipeline with data_path pointing to a fixed locale dump' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dump.de.dataPath[]'
        }
      }
      source_filter = { 'dump.de.dataPath.type' => 'type' }
      exp = [
        { '$match' => { 'dump.de.dataPath.id' => { '$exists' => true }, 'dump.de.dataPath.type' => 'type' } },
        { '$project' => { 'data' => '$dump', 'add_data' => nil, 'external_system' => 1 } },
        { '$project' => { 'data' => '$data.de', 'add_data' => '$add_data', 'external_system' => 1 } },
        { '$project' => { 'data' => '$data.dataPath', 'add_data' => '$add_data', 'external_system' => 1 } },
        { '$unwind' => '$data' },
        { '$match' => { 'data.id' => { '$exists' => true }, 'data.type' => 'type' } },
        { '$addFields' =>
          { 'data.id' => { '$ifNull' => ['$data.id', '$data.name'] },
            'data.name' => '$data.name' } },
        { '$group' => { '_id' => '$data.id', 'data' => { '$first' => '$data' }, 'external_system' => { '$mergeObjects' => '$external_system' } } },
        { '$addFields' => { 'data.external_system' => '$external_system' } },
        { '$replaceRoot' => { 'newRoot' => '$data' } },
        { '$addFields' => { 'name' => { '$trim' => { 'input' => { '$toString' => '$name' } } } } },
        { '$match' => { 'id' => { '$nin' => [nil, ''] } } }
      ]

      # the pipeline is independent of the imported locale
      ['en', 'de'].each do |locale|
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)

        assert_equal exp, pipelines
      end
    end

    # Redmine #50469: without data_sorting the $group keeps whichever item reached it first, which is storage
    # order. Feratel repeats one event address on every event with diverging payloads, so the survivor was arbitrary.
    test 'data_sorting adds a $sort before the $group and carries the value through the unwind' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[]',
          data_sorting: { 'updated_at' => 'desc' }
        }
      }

      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)

      assert_equal({ 'sort_values' => { 'k0' => '$updated_at' } }, pipelines[1]['$project'].slice('sort_values'))

      sort_index = pipelines.index { |s| s.key?('$sort') }
      group_index = pipelines.index { |s| s.key?('$group') }

      assert_equal({ 'sort_values.k0' => -1, '_id' => 1 }, pipelines[sort_index]['$sort'])
      assert_operator sort_index, :<, group_index
      # $replaceRoot promotes $data, so the carried value never reaches the target collection
      assert_equal({ 'newRoot' => '$data' }, pipelines.find { |s| s.key?('$replaceRoot') }['$replaceRoot'])
    end

    test 'data_sorting accepts every direction spelling and rejects anything else' do
      base = { data_id_path: 'id', data_name_path: 'name', data_path: 'dataPath[]' }

      { 'desc' => -1, 'descending' => -1, -1 => -1, 'asc' => 1, 'ascending' => 1, 1 => 1 }.each do |given, expected|
        options = { download: base.merge(data_sorting: { 'updated_at' => given }) }
        pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)

        assert_equal({ 'sort_values.k0' => expected, '_id' => 1 }, pipelines.find { |s| s.key?('$sort') }['$sort'], "direction #{given.inspect}")
      end

      options = { download: base.merge(data_sorting: { 'updated_at' => 'newest' }) }

      assert_raises ArgumentError do
        DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)
      end
    end

    # A second $sort would undo the first, so both jobs share one stage. data_sorting leads, or adding
    # group_to_array_paths would change what a step keeps; _id trails, or it takes over the $push order.
    test 'data_sorting and group_to_array_paths share one $sort, data_sorting first and _id last' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[]',
          data_sorting: { 'updated_at' => 'desc' },
          group_to_array_paths: ['attr1']
        }
      }

      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)
      sorts = pipelines.select { |s| s.key?('$sort') }

      assert_equal 1, sorts.size
      assert_equal [['sort_values.k0', -1], ['data.attr1', 1], ['_id', 1]], sorts.first['$sort'].to_a
    end

    # the tiebreaker rides on data_sorting, so a step without it keeps its pipeline - including the
    # group_to_array_paths ones, whose $sort would otherwise gain a key
    test 'group_to_array_paths without data_sorting sorts as before, without _id' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[]',
          group_to_array_paths: ['attr1']
        }
      }

      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)

      assert_equal({ 'data.attr1' => 1 }, pipelines.find { |s| s.key?('$sort') }['$sort'])
    end

    # neither `locale` nor the imported locale exists in the binding with_evaluated_values defaults to,
    # so prepare_data_sorting passes its own and pushes I18n.locale around it - both spellings resolve
    test 'data_sorting resolves a templated key against the imported locale' do
      base = { data_id_path: 'id', data_name_path: 'name', data_path: 'dataPath[]' }

      # single quoted on purpose: the '#{locale}' belongs to the config template, not to ruby
      ['{{ "dump.#{locale}.ChangeDate" }}', "{{ ['dump', I18n.locale, 'ChangeDate'].join('.') }}"].each do |key| # rubocop:disable Lint/InterpolationCheck
        options = { download: base.merge(data_sorting: { key => 'desc' }) }

        I18n.with_locale(:en) do
          pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)

          assert_equal({ 'sort_values' => { 'k0' => '$dump.de.ChangeDate' } }, pipelines[1]['$project'].slice('sort_values'), "key #{key}")
        end
      end
    end

    # '- updated_at: desc' is what a config author writes when key order matters, and it used to fail
    # on the direction (nil) rather than on the shape
    test 'data_sorting reads the ordered list the same way as the mapping' do
      base = { data_id_path: 'id', data_name_path: 'name', data_path: 'dataPath[]' }

      as_list = { download: base.merge(data_sorting: [{ 'updated_at' => 'desc' }, { 'id' => 'asc' }]) }
      as_mapping = { download: base.merge(data_sorting: { 'updated_at' => 'desc', 'id' => 'asc' }) }

      list_pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: as_list, locale: 'de', source_filter: nil)
      mapping_pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options: as_mapping, locale: 'de', source_filter: nil)

      assert_equal mapping_pipelines, list_pipelines
      assert_equal({ 'sort_values.k0' => -1, 'sort_values.k1' => 1, '_id' => 1 }, list_pipelines.find { |s| s.key?('$sort') }['$sort'])

      # the scalar has to be caught before with_evaluated_values, which reports a missing method on String
      [['updated_at'], 'updated_at'].each do |given|
        options = { download: base.merge(data_sorting: given) }

        error = assert_raises(ArgumentError, "data_sorting #{given.inspect}") do
          DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)
        end

        assert_includes error.message, 'expected a path => direction mapping'
      end
    end

    # the id set does not depend on which duplicate the $group keeps, so the bulk passes must not pay for the
    # sort - bulk_mark_deleted also reads the target collection, where a source path need not resolve at all
    test 'data_sorting is dropped for the id-only and bulk_mark_deleted passes' do
      options = {
        download: {
          name: 'collect_things',
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[]',
          data_sorting: { 'updated_at' => 'desc' }
        }
      }

      reset = DataCycleCore::Generic::Common::DownloadDataFromData.bulk_mark_deleted_options(options:, last_download: Time.zone.now)

      assert_nil reset.dig(:download, :data_sorting)

      captured = nil
      record = lambda do |**kwargs|
        captured = kwargs[:options]
        []
      end

      DataCycleCore::Generic::Common::DownloadDataFromData.stub(:load_data_from_mongo, record) do
        DataCycleCore::Generic::Common::DownloadDataFromData.load_ids_from_mongo(options:, locale: 'de', source_filter: nil)
      end

      assert_nil captured.dig(:download, :data_sorting)
    end

    test 'no data_sorting leaves the pipeline exactly as it was' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[]'
        }
      }

      pipelines = DataCycleCore::Generic::Common::DownloadDataFromData.create_aggregate_pipeline(options:, locale: 'de', source_filter: nil)

      assert_empty(pipelines.select { |s| s.key?('$sort') })
      assert_not_includes pipelines.to_json, 'sort_values'
    end
  end
end
