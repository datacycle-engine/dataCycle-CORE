# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Generic::Common::ExternalReferenceTransformations do
  subject do
    DataCycleCore::Generic::Common::ExternalReferenceTransformations
  end

  it 'should create external reference for single content' do
    raw_data = {
      'content_id' => 'SOME EXTERNAL ID'
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID', ['content_id'])

    assert_equal(1, transformed_data['content'].size)

    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].first.external_source_id)
    assert_equal('SOME EXTERNAL ID', transformed_data['content'].first.external_key)
  end

  it 'should create external references for multiple contents' do
    raw_data = {
      'contents' => [
        { 'id' => 'EXTERNAL ID ONE' },
        { 'id' => 'EXTERNAL ID TWO' },
        { 'id' => 'EXTERNAL ID THREE' }
      ]
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID', ['contents', 'id'])

    assert_equal(3, transformed_data['content'].size)

    assert_equal(1, transformed_data['content'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].map(&:external_source_id).first)

    assert_equal(3, transformed_data['content'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'EXTERNAL ID ONE')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'EXTERNAL ID TWO')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'EXTERNAL ID THREE')
  end

  it 'should create external references for deeply nested contents' do
    raw_data = {
      'contents_1' => [
        {
          'contents_2' => [
            {
              'contents_3' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ]
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                               ['contents_1', 'contents_2', 'contents_3', 'id'])

    assert_equal(2, transformed_data['content'].size)

    assert_equal(1, transformed_data['content'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].map(&:external_source_id).first)

    assert_equal(2, transformed_data['content'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'SOME EXTERNAL ID')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'ANOTHER EXTERNAL ID')
  end

  it 'should create external classification references' do
    raw_data = {
      'classifications_1' => [
        {
          'classifications_1_1' => [
            {
              'classifications_1_1_1' => [
                { 'id' => 'EXTERNAL ID ONE' },
                { 'id' => 'EXTERNAL ID TWO' }
              ]
            }
          ]
        }
      ],
      'classification_ids_2' => [
        { 'id' => 'EXTERNAL ID THREE' },
        { 'id' => 'EXTERNAL ID FOUR' },
        { 'id' => 'EXTERNAL ID FIVE' }
      ]
    }

    transformed_data = subject.add_external_classification_references(
      raw_data, 'classifications_1', 'EXTERNAL SOURCE ID',
      ['classifications_1', 'classifications_1_1', 'classifications_1_1_1', 'id']
    )
    transformed_data = subject.add_external_classification_references(
      transformed_data, 'classifications_2', 'EXTERNAL SOURCE ID', ['classification_ids_2', 'id']
    )

    assert_equal(2, transformed_data['classifications_1'].size)

    assert_equal(1, transformed_data['classifications_1'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['classifications_1'].map(&:external_source_id).first)

    assert_equal(2, transformed_data['classifications_1'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['classifications_1'].map(&:external_key).uniq, 'EXTERNAL ID ONE')
    assert_includes(transformed_data['classifications_1'].map(&:external_key).uniq, 'EXTERNAL ID TWO')

    assert_equal(3, transformed_data['classifications_2'].size)

    assert_equal(1, transformed_data['classifications_2'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['classifications_2'].map(&:external_source_id).first)

    assert_equal(3, transformed_data['classifications_2'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['classifications_2'].map(&:external_key).uniq, 'EXTERNAL ID THREE')
    assert_includes(transformed_data['classifications_2'].map(&:external_key).uniq, 'EXTERNAL ID FOUR')
    assert_includes(transformed_data['classifications_2'].map(&:external_key).uniq, 'EXTERNAL ID FIVE')
  end

  it 'should resolve external content references' do
    raw_data = {
      'contents_1' => [
        {
          'contents_2' => [
            {
              'contents_3' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ],
      'additional_content' => { 'id' => 'SOME ADDITIONAL EXTERNAL ID' }
    }

    transformed_data = subject.add_external_content_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                               ['contents_1', 'contents_2', 'contents_3', 'id'])
    transformed_data = subject.add_external_content_references(transformed_data, 'additional_content', 'EXTERNAL SOURCE ID',
                                                               ['additional_content', 'id'])

    load_things_stub = lambda do |_external_source_id, _external_keys|
      {
        'SOME EXTERNAL ID' => '00000000-0000-0000-0000-000000000001',
        'ANOTHER EXTERNAL ID' => '00000000-0000-0000-0000-000000000002',
        'SOME ADDITIONAL EXTERNAL ID' => '00000000-0000-0000-0000-000000000003'
      }
    end

    subject.stub :load_things, load_things_stub do
      transformed_data = subject.resolve_external_references(transformed_data)

      assert_equal(2, transformed_data['content'].size)
      assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000002')

      assert_equal(1, transformed_data['additional_content'].size)
      assert_includes(transformed_data['additional_content'], '00000000-0000-0000-0000-000000000003')
    end
  end

  it 'should resolve external classification references' do
    raw_data = {
      'classification_1' => [
        {
          'classification_2' => [
            {
              'classification_3' => [
                { 'id' => 'SOME EXTERNAL ID' },
                { 'id' => 'ANOTHER EXTERNAL ID' }
              ]
            }
          ]
        }
      ],
      'additional_classification' => { 'id' => 'SOME ADDITIONAL EXTERNAL ID' }
    }

    transformed_data = subject.add_external_classification_references(raw_data, 'classification', 'EXTERNAL SOURCE ID',
                                                                      ['classification_1', 'classification_2', 'classification_3', 'id'])
    transformed_data = subject.add_external_classification_references(transformed_data, 'additional_classification', 'EXTERNAL SOURCE ID',
                                                                      ['additional_classification', 'id'])

    load_classifications_stub = lambda do |_external_source_id, _external_keys|
      {
        'SOME EXTERNAL ID' => '00000000-0000-0000-0000-000000000001',
        'ANOTHER EXTERNAL ID' => '00000000-0000-0000-0000-000000000002',
        'SOME ADDITIONAL EXTERNAL ID' => '00000000-0000-0000-0000-000000000003'
      }
    end

    subject.stub :load_classifications, load_classifications_stub do
      transformed_data = subject.resolve_external_references(transformed_data)

      assert_equal(2, transformed_data['classification'].size)
      assert_includes(transformed_data['classification'], '00000000-0000-0000-0000-000000000001')
      assert_includes(transformed_data['classification'], '00000000-0000-0000-0000-000000000002')

      assert_equal(1, transformed_data['additional_classification'].size)
      assert_includes(transformed_data['additional_classification'], '00000000-0000-0000-0000-000000000003')
    end
  end

  it 'should resolve mixed external references' do
    raw_data = {
      'content' => { 'id' => 'EXTERNAL CONTENT ID' },
      'classification' => { 'id' => 'EXTERNAL CLASSIFICATION ID' }
    }

    transformed_data = subject.add_external_classification_references(raw_data, 'classification', 'EXTERNAL SOURCE ID',
                                                                      ['classification', 'id'])
    transformed_data = subject.add_external_content_references(transformed_data, 'content', 'EXTERNAL SOURCE ID',
                                                               ['content', 'id'])

    load_data_stub = lambda do |_reference_type, _external_source_id, _external_keys|
      {
        'EXTERNAL CONTENT ID' => '00000000-0000-0000-0000-000000000001',
        'EXTERNAL CLASSIFICATION ID' => '00000000-0000-0000-0001-000000000002'
      }
    end

    subject.stub :load_data, load_data_stub do
      transformed_data = subject.resolve_external_references(transformed_data)

      assert_equal(1, transformed_data['content'].size)
      assert_includes(transformed_data['content'], '00000000-0000-0000-0000-000000000001')

      assert_equal(1, transformed_data['classification'].size)
      assert_includes(transformed_data['classification'], '00000000-0000-0000-0001-000000000002')
    end
  end
end
