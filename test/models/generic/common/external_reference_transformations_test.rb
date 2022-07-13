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

    transformed_data = subject.add_external_references(raw_data, 'content', 'EXTERNAL SOURCE ID', ['content_id'])

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

    transformed_data = subject.add_external_references(raw_data, 'content', 'EXTERNAL SOURCE ID', ['contents', 'id'])

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

    transformed_data = subject.add_external_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                       ['contents_1', 'contents_2', 'contents_3', 'id'])

    assert_equal(2, transformed_data['content'].size)

    assert_equal(1, transformed_data['content'].map(&:external_source_id).uniq.size)
    assert_equal('EXTERNAL SOURCE ID', transformed_data['content'].map(&:external_source_id).first)

    assert_equal(2, transformed_data['content'].map(&:external_key).uniq.size)
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'SOME EXTERNAL ID')
    assert_includes(transformed_data['content'].map(&:external_key).uniq, 'ANOTHER EXTERNAL ID')
  end

  it 'should resolve external references' do
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

    transformed_data = subject.add_external_references(raw_data, 'content', 'EXTERNAL SOURCE ID',
                                                       ['contents_1', 'contents_2', 'contents_3', 'id'])
    transformed_data = subject.add_external_references(transformed_data, 'additional_content', 'EXTERNAL SOURCE ID',
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
end
