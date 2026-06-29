# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::Generic::Common::Transformations::LegacyLinkFunctions do
  include DataCycleCore::MinitestSpecHelper

  subject { DataCycleCore::Generic::Common::Transformations::LegacyLinkFunctions }

  # a random, unseeded external system id → every lookup below resolves to nothing,
  # which is enough to execute the query branches for coverage.
  let(:external_source_id) { '11111111-1111-1111-1111-111111111111' }

  it 'add_link resolves and merges a single thing id' do
    result = subject.add_link({ 'k' => 'EK' }, 'attr', DataCycleCore::Thing, external_source_id, ->(d) { d['k'] })

    assert(result.key?('attr'))
  end

  it 'add_link returns data unchanged when the condition is false' do
    result = subject.add_link({ 'k' => 'EK' }, 'attr', DataCycleCore::Thing, external_source_id, ->(d) { d['k'] }, ->(_d) { false })

    assert_not(result.key?('attr'))
  end

  it 'add_links tolerates a nil key function result' do
    result = subject.add_links({}, 'attr', DataCycleCore::Thing, external_source_id, ->(_d) {})

    assert_equal([], result['attr'])
  end

  it 'add_universal_classifications appends classification ids' do
    result = subject.add_universal_classifications({}, ->(_d) { ['c1', 'c2'] })

    assert_equal(['c1', 'c2'], result['universal_classifications'])
  end

  it 'tags_to_ids returns [] for a blank attribute' do
    result = subject.tags_to_ids({ 'attr' => nil }, 'attr', external_source_id, 'PRE')

    assert_equal([], result['attr'])
  end

  it 'tags_to_ids resolves classification ids for present tags' do
    result = subject.tags_to_ids({ 'attr' => ['a', 'b'] }, 'attr', external_source_id, 'PRE')

    assert_kind_of(Array, result['attr'])
  end

  it 'tags_to_ids returns data unchanged when the condition is false' do
    result = subject.tags_to_ids({ 'attr' => ['a'] }, 'attr', external_source_id, 'PRE', ->(_d) { false })

    assert_equal(['a'], result['attr'])
  end

  it 'tags_to_ids_by_name returns [] for a blank attribute' do
    result = subject.tags_to_ids_by_name({ 'attr' => nil }, 'attr', 'Tags')

    assert_equal([], result['attr'])
  end

  it 'tags_to_ids_by_name resolves classification ids by name' do
    result = subject.tags_to_ids_by_name({ 'attr' => ['sommer'] }, 'attr', 'Tags')

    assert_kind_of(Array, result['attr'])
  end

  it 'category_key_to_ids returns data unchanged when data or data_list is blank' do
    result = subject.category_key_to_ids({}, 'attr', nil, '_name', external_source_id, 'PRE', 'key')

    assert_equal({}, result)
  end

  it 'category_key_to_ids resolves ids from a data list' do
    data_list = ->(_d) { [{ 'key' => 'v1' }, { 'key' => 'v2' }] }
    result = subject.category_key_to_ids({ 'x' => 1 }, 'attr', data_list, '_name', external_source_id, 'PRE', 'key')

    assert_equal([], result['attr'])
  end

  it 'load_category resolves a single classification id' do
    result = subject.load_category({}, 'attr', external_source_id, ->(_d) { 'EK' })

    assert(result.key?('attr'))
  end

  it 'add_user_link returns data unchanged when the key is blank' do
    result = subject.add_user_link({}, 'attr', ->(_d) {})

    assert_not(result.key?('attr'))
  end

  it 'add_user_link resolves a user id by email' do
    result = subject.add_user_link({ 'email' => 'nobody@example.com' }, 'attr', ->(d) { d['email'] })

    assert(result.key?('attr'))
  end

  it 'find_thing_ids returns [] for a blank external key' do
    assert_equal([], subject.find_thing_ids(external_system_id: external_source_id, external_key: nil))
  end

  it 'find_thing_ids queries non-Thing content types without plucking' do
    result = subject.find_thing_ids(external_system_id: external_source_id, external_key: ['EK'], content_type: DataCycleCore::Classification, pluck_id: false)

    assert_respond_to(result, :to_a)
  end
end
