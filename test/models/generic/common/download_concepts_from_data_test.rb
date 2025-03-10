# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DownloadConceptsFromDataTest < ActiveSupport::TestCase
    test 'data_id_path is nil' do
      options = {
        download: {
          data_id_path: nil,
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal 'name', paths['data_id_path']
        assert_equal 'name', paths['data_name_path']
        assert_equal "dump.#{locale}.dataPath.name", paths['full_id_path']
        assert_equal "dump.#{locale}.dataPath", paths['full_data_path']
        assert_equal 'dataPath', paths['data_path']
      end
    end

    test 'data_id_path key is not defined' do
      options = {
        download: {
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal 'name', paths['data_id_path']
        assert_equal 'name', paths['data_name_path']
        assert_equal "dump.#{locale}.dataPath.name", paths['full_id_path']
        assert_equal "dump.#{locale}.dataPath", paths['full_data_path']
        assert_equal 'dataPath', paths['data_path']
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
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal 'id', paths['data_id_path']
        assert_equal 'id', paths['data_name_path']
        assert_equal "dump.#{locale}.dataPath.id", paths['full_id_path']
        assert_equal "dump.#{locale}.dataPath", paths['full_data_path']
        assert_equal 'dataPath', paths['data_path']
      end
    end

    test 'data_name_path key is not defined' do
      options = {
        download: {
          data_id_path: 'id',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal 'id', paths['data_id_path']
        assert_equal 'id', paths['data_name_path']
        assert_equal "dump.#{locale}.dataPath.id", paths['full_id_path']
        assert_equal "dump.#{locale}.dataPath", paths['full_data_path']
        assert_equal 'dataPath', paths['data_path']
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
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal 'id', paths['data_id_path']
        assert_equal 'name', paths['data_name_path']
        assert_equal "dump.#{locale}.id", paths['full_id_path']
        assert_equal "dump.#{locale}", paths['full_data_path']
        assert_equal '', paths['data_path']
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
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal 'id', paths['data_id_path']
        assert_equal 'name', paths['data_name_path']
        assert_equal "dump.#{locale}.id", paths['full_id_path']
        assert_equal "dump.#{locale}", paths['full_data_path']
        assert_equal '', paths['data_path']
      end
    end

    test 'data_name_path have erb evaluations' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: '<%= "name.#{locale}" %>',
          data_path: 'dataPath'
        }
      }
      ['en', 'de'].each do |locale|
        paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
        assert_equal "name.#{locale}", paths['data_name_path']
      end
    end

    test 'array postions in data_path are correctly identified and path correctly transformed 1' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath[].arr[].obj.name'
        }
      }
      locale = :de
      paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
      assert_equal [1, 1, 0, 1], paths['path_array_positions']
      assert_equal 'dataPath.arr.obj.name', paths['data_path']
    end

    test 'array postions in data_path are correctly identified and path correctly transformed 2' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath.obj.name'
        }
      }
      locale = :de
      paths = DataCycleCore::Generic::Common::DownloadConceptsFromData.prepare_data_paths(options:, locale:)
      assert_equal [0, 0, 1], paths['path_array_positions']
      assert_equal 'dataPath.obj.name', paths['data_path']
    end

    # from here test the piplelines

    test 'trim_name option set to true by default' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$addFields' => {'name' => {'$trim' => {'input' => '$name'}}}}
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
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$addFields' => {'name' => {'$trim' => {'input' => '$name'}}}}
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$addFields') }
      assert_not_equal exp, relevant_pipeline
    end

    test 'assures that data with nil id and name are filtered out' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$match' => {'id' => {'$ne' => nil}, 'name' => {'$ne' => nil}}}
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
        pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)
        exp = [
          {'$project' => {'data' => "$dump.#{locale}.dataPath"}},
          {'$unwind' => '$data'},
          {'$match' => {'data.arr.obj.id' => {'$exists' => true}, 'data.arr.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.arr'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.obj.id' => {'$exists' => true}, 'data.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.obj'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}}
        ]
        first_index = pipelines.find_index { |p| p.key?('$project') } # first projection stage
        last_index = pipelines.rindex { |p| p.key?('$unwind') } # last unwind stage
        assert_equal exp, pipelines[first_index..last_index + 1]
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
        pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)
        exp = [
          {'$project' => {'data' => "$dump.#{locale}.dataPath"}},
          {'$project' => {'data' => '$data.obj'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}}
        ]
        first_index = pipelines.find_index { |p| p.key?('$project') } # first projection stage
        last_index = pipelines.rindex { |p| p.key?('$unwind') } # last unwind stage
        assert_equal exp, pipelines[first_index..last_index + 1]
      end
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
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$addFields' => {'id' => {'$concat' => [options.dig(:download, :data_id_prefix), '$id']}, 'parent_id' => {'$concat' => [options.dig(:download, :data_id_prefix), '$parent_id']}}}
      assert_equal exp, pipelines.last
    end

    test 'data_id_prefix is correctly added to parent_id' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          concept_parent_id_path: 'some_parent_id_path',
          data_id_prefix: 'prefix_'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$addFields' => {'id' => {'$concat' => [options.dig(:download, :data_id_prefix), '$id']}, 'parent_id' => {'$concat' => [options.dig(:download, :data_id_prefix), '$parent_id']}}}
      assert_equal exp, pipelines.last
    end

    test 'data_id_prefix and external_id_prefix cannot be defined together' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          data_id_prefix: 'prefix_',
          external_id_prefix: 'external_'
        }
      }
      locale = :de
      assert_raises ArgumentError do
        DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      end
    end

    test 'final_projection_stage projects relevant info 1' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$project' => {'data.id' => '$data.id', 'data.name' => '$data.name', 'data.parent_id' => '$data.parent_id', 'data.uri' => '$data.uri', 'data.priority' => 5}}
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$project') }
      assert_equal exp, relevant_pipeline
    end

    test 'final_projection_stage projects relevant info 2' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          priority: 3,
          concept_uri_path: 'uri_path',
          concept_parent_id_path: 'parent_id_path'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$project' => {'data.id' => '$data.id', 'data.name' => '$data.name', 'data.parent_id' => '$data.parent_id_path', 'data.uri' => '$data.uri_path', 'data.priority' => 3}}
      relevant_pipeline = pipelines.reverse.find { |p| p.key?('$project') }
      assert_equal exp, relevant_pipeline
    end

    test 'name and id are alsways stringified' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath'
        }
      }
      locale = :de
      pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: {})
      exp = {'$addFields' => {'name' => {'$toString' => '$name'}, 'id' => {'$toString' => '$id'}}}
      relevant_pipelines = pipelines.select { |p| p.key?('$addFields') }
      assert_includes relevant_pipelines, exp
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
        pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter: source_filter)
        exp = [
          {'$match' => {"dump.#{locale}.dataPath.arr.obj.id" => {'$exists' => true}, "dump.#{locale}.dataPath.arr.obj.type" => 'type'}},
          {'$project' => {'data' => "$dump.#{locale}.dataPath"}},
          {'$unwind' => '$data'},
          {'$match' => {'data.arr.obj.id' => {'$exists' => true}, 'data.arr.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.arr'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.obj.id' => {'$exists' => true}, 'data.obj.type' => 'type'}},
          {'$project' => {'data' => '$data.obj'}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}},
          {'$project' => {'data.id' => '$data.id', 'data.name' => '$data.name', 'data.parent_id' => '$data.parent_id', 'data.uri' => '$data.uri', 'data.priority' => 5}},
          {'$group' => {'_id' => '$data.id', 'data' => {'$first' => '$data'}}},
          {'$replaceRoot' => {'newRoot' => '$data'}},
          {'$addFields' => {'name' => {'$toString' => '$name'}, 'id' => {'$toString' => '$id'}}},
          {'$addFields' => {'name' => {'$trim' => {'input' => '$name'}}}},
          {'$match' => {'id' => {'$ne' => nil}, 'name' => {'$ne' => nil}}}
        ]
        assert_equal exp, pipelines
      end
    end

    test 'test complex pipeline 2' do
      options = {
        download: {
          data_id_path: 'id',
          data_name_path: 'name',
          data_path: 'dataPath',
          concept_parent_id_path: 'parent_id_path',
          concept_uri_path: 'uri_path'
        }
      }
      ['en', 'de'].each do |locale|
        source_filter = { "dump.#{locale}.dataPath.type" => 'type' }
        pipelines = DataCycleCore::Generic::Common::DownloadConceptsFromData.create_aggregate_pipeline(options: options, locale:, source_filter:)
        exp = [
          {'$match' => {"dump.#{locale}.dataPath.id" => {'$exists' => true}, "dump.#{locale}.dataPath.type" => 'type'}},
          {'$project' => {'data' => "$dump.#{locale}.dataPath"}},
          {'$unwind' => '$data'},
          {'$match' => {'data.id' => {'$exists' => true}, 'data.type' => 'type'}},
          {'$project' => {'data.id' => '$data.id', 'data.name' => '$data.name', 'data.parent_id' => '$data.parent_id_path', 'data.uri' => '$data.uri_path', 'data.priority' => 5}},
          {'$group' => {'_id' => '$data.id', 'data' => {'$first' => '$data'}}},
          {'$replaceRoot' => {'newRoot' => '$data'}},
          {'$addFields' => {'name' => {'$toString' => '$name'}, 'id' => {'$toString' => '$id'}}},
          {'$addFields' => {'name' => {'$trim' => {'input' => '$name'}}}},
          {'$match' => {'id' => {'$ne' => nil}, 'name' => {'$ne' => nil}}}
        ]
        assert_equal exp, pipelines
      end
    end
  end
end
