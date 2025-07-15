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
          data_name_path: '<%= "name.#{locale}" %>',
          data_path: 'dataPath',
          data_name_path_fallback: [
            '<%= "name_#{locale}" %>'
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
          'attr2' => "$dump.#{locale}.path2",
          'external_system' => '$external_system'
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
          'attr2' => "$dump.#{locale}.path2",
          'external_system' => '$external_system'
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
        exp = {
          'external_system' => '$external_system'
        }
        assert_equal exp, paths['additional_paths']
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
        exp = {
          'external_system' => '$external_system'
        }
        assert_equal exp, paths['additional_paths']
      end
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
      exp = { '$project' => { 'id' => 1, 'name' => 1, 'attr1' => 1, 'attr2' => 1, 'external_system' => 1 } }
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
      exp = {'$addFields' => {'id' => {'$concat' => [options.dig(:download, :data_id_prefix), { '$toString' => '$id' }]}}}
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
      exp = { '$match' => { 'id' => { '$ne' => nil } } }
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
          {'$project' => {'data' => "$dump.#{locale}.dataPath", 'add_data' => {'external_system' => '$external_system'}}},
          {'$unwind' => '$data'},
          {'$match' => {'data.arr.obj.id' => {'$exists' => true}, 'data.arr.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.arr', 'add_data' => '$add_data'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.obj.id' => {'$exists' => true}, 'data.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.obj', 'add_data' => '$add_data'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}}
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
          {'$project' => {'data' => "$dump.#{locale}.dataPath", 'add_data' => {'external_system' => '$external_system'}}},
          {'$project' => {'data' => '$data.obj', 'add_data' => '$add_data'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}}
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
          {'$match' => {"dump.#{locale}.dataPath.arr.obj.id" => {'$exists' => true}, "dump.#{locale}.dataPath.arr.obj.type" => 'type'}},
          {'$project' => {'data' => "$dump.#{locale}.dataPath", 'add_data' => {'external_system' => '$external_system'}}},
          {'$unwind' => '$data'},
          {'$match' => {'data.arr.obj.id' => {'$exists' => true}, 'data.arr.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.arr', 'add_data' => '$add_data'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.obj.id' => {'$exists' => true}, 'data.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.obj', 'add_data' => '$add_data'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}},
          {'$addFields' =>
            {'data.id' => {'$ifNull' => ['$data.id', '$data.name']},
             'data.name' => '$data.name',
             'data.external_system' => '$external_system'}},
          {'$group' => {'_id' => '$data.id', 'data' => {'$first' => '$data'}}},
          {'$replaceRoot' => {'newRoot' => '$data'}},
          {'$addFields' => {'name' => {'$trim' => {'input' => {'$toString' => '$name'}}}}},
          {'$match' => {'id' => {'$ne' => nil}}}
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
          {'$match' => {"dump.#{locale}.dataPath.author" => {'$exists' => true}}},
          {'$project' => {'data' => "$dump.#{locale}.dataPath", 'add_data' => {'external_system' => '$external_system'}}},
          {'$unwind' => '$data'},
          {'$match' => {'data.author' => {'$exists' => true}}},
          {'$project' => {'data' => '$data.author', 'add_data' => '$add_data'}},
          {'$unwind' => '$data'},
          {'$match' => {'data' => {'$exists' => true}}},
          {'$addFields' => {'data.id' => '$data', 'data.name' => '$data', 'data.external_system' => '$external_system'}},
          {'$group' => {'_id' => '$data.id', 'data' => {'$first' => '$data'}}},
          {'$replaceRoot' => {'newRoot' => '$data'}},
          {'$addFields' => {'name' => {'$trim' => {'input' => {'$toString' => '$name'}}}}},
          {'$match' => {'id' => {'$ne' => nil}}}
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
          {'$match' => {"dump.#{locale}.dataPath.id" => {'$exists' => true}, "dump.#{locale}.dataPath.type" => 'type'}},
          {'$project' =>
            {'data' => "$dump.#{locale}.dataPath",
             'add_data' => {'attr1' => "$dump.#{locale}.path1", 'external_system' => '$external_system'}}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}},
          {'$addFields' =>
            {'data.id' => {'$ifNull' => ['$data.id', '$data.name']},
             'data.name' => '$data.name',
             'data.attr1' => {'$ifNull' => ['$data.attr1', '$add_data.attr1']},
             'data.external_system' => '$external_system'}},
          {'$group' => {'_id' => '$data.id', 'data' => {'$first' => '$data'}}},
          {'$replaceRoot' => {'newRoot' => '$data'}},
          {'$addFields' => {'name' => {'$trim' => {'input' => {'$toString' => '$name'}}}}},
          {'$project' => {'attr1' => 1, 'attr2' => 1, 'id' => 1, 'name' => 1, 'external_system' => 1}},
          {'$match' => {'id' => {'$ne' => nil}}}
        ]
        assert_equal exp, pipelines
      end
    end
  end
end
