# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentMongoRawDataTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Mongo Raw Data Test System',
        identifier: 'mongo-raw-data-test-system'
      )
      @collection_name = 'raw_data_things'
      @key = 'raw-1'
      @dump = { 'de' => { 'id' => @key, 'name' => 'Raw Item' } }

      seed_mongo(@external_source, @collection_name, @key, @dump)
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('mongo-raw-data-test-system')
    end

    # seeds a document into the external system's MongoDB the same way an import would
    def seed_mongo(external_source, collection_name, external_id, dump)
      external_source.query(collection_name) do |collection|
        item = collection.find_or_initialize_by(external_id:)
        item.dump = dump
        item.save!
      end
    end

    # Creates real Artikel content whose dc_mongo_collection/dc_mongo_key values come from the
    # meta_data template properties (no stubbing). Each scenario needs a unique name because
    # TestPreparations.create_content dedups by template_name + name and only writes the data_hash
    # on first creation — reusing a name would silently keep another scenario's mongo values.
    def content_with_mongo_ref(name:, collection_name:, key:, external_source: @external_source)
      content = DataCycleCore::TestPreparations.create_content(
        template_name: 'Artikel',
        data_hash: { name:, dc_mongo_collection: collection_name, dc_mongo_key: key }
      )
      content.update_columns(external_source_id: external_source&.id)
      content
    end

    test 'returns the dump hash of the referenced mongo document' do
      content = content_with_mongo_ref(name: 'Raw Data valid ref', collection_name: @collection_name, key: @key)

      assert_equal(@dump, content.mongo_raw_data)
    end

    test 'returns nil when no document matches the mongo_key' do
      content = content_with_mongo_ref(name: 'Raw Data missing document', collection_name: @collection_name, key: 'does-not-exist')

      assert_nil(content.mongo_raw_data)
    end

    test 'returns nil when external_source is missing' do
      content = content_with_mongo_ref(name: 'Raw Data no external source', collection_name: @collection_name, key: @key, external_source: nil)

      assert_nil(content.mongo_raw_data)
    end

    test 'returns nil when mongo_collection is blank' do
      content = content_with_mongo_ref(name: 'Raw Data blank collection', collection_name: nil, key: @key)

      assert_nil(content.mongo_raw_data)
    end

    test 'returns nil when mongo_key is blank' do
      content = content_with_mongo_ref(name: 'Raw Data blank key', collection_name: @collection_name, key: nil)

      assert_nil(content.mongo_raw_data)
    end

    test 'returns nil when the mongo_collection/mongo_key properties are left unset' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'No Mongo Ref' })
      content.update_columns(external_source_id: @external_source.id)

      assert_nil(content.mongo_raw_data)
    end
  end
end
