# frozen_string_literal: true

require 'test_helper'
require 'virtual_attributes_test_utilities'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe 'DataCycleCore::Utility::Virtual::Classification#concat' do
  include VirtualAttributeTestUtilities

  subject do
    DataCycleCore::Utility::Virtual::Classification
  end

  it 'should concat classification aliases of multiple classifications' do
    content = create_content_dummy({
      my_classification:
        create_classification_dummy([{
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One',
          classification_aliases: create_classification_alias_dummy([{
            id: '10000000-0000-0000-0000-000000000001',
            internal_name: 'One',
            name_i18n: {
              en: 'One',
              de: 'Eins'
            }
          }])
        }]),
      my_classification_two:
        create_classification_dummy([{
          id: '00000000-0000-0000-0000-000000000002',
          name: 'Two',
          classification_aliases: create_classification_alias_dummy([{
            id: '10000000-0000-0000-0000-000000000002',
            internal_name: 'Two',
            name_i18n: {
              en: 'Two',
              de: 'Zwei'
            }
          }])
        }])
    })

    value = {}

    [:de, :en].each do |locale|
      I18n.with_locale(locale) do
        value[locale] = subject.concat(virtual_definition: { 'virtual' => {'key' => 'name'} }.with_indifferent_access, content:, virtual_parameters: ['my_classification', 'my_classification_two'])
      end
    end
    assert_equal('One, Two', value[:en])
    assert_equal('Eins, Zwei', value[:de])
  end

  it 'should handle emtpy classifications (multiple)' do
    content = create_content_dummy({
      my_classification: [],
      my_classification_two: []
    })

    value = subject.concat(virtual_definition: { 'virtual' => {'key' => 'name'} }.with_indifferent_access, content:, virtual_parameters: ['my_classification', 'my_classification_two'])

    assert_nil(value)
  end

  it 'should handle emtpy classifications in combination with non-empty classifications' do
    content = create_content_dummy({
      my_classification: [],
      my_classification_two: create_classification_dummy([{
        id: '00000000-0000-0000-0000-000000000002',
        name: 'Two',
        classification_aliases: create_classification_alias_dummy([{
          id: '10000000-0000-0000-0000-000000000002',
          internal_name: 'Two',
          name_i18n: {
            en: 'Two',
            de: 'Zwei'
          }
        }])
      }])
    })

    value = {}
    [:de, :en].each do |locale|
      I18n.with_locale(locale) do
        value[locale] = subject.concat(virtual_definition: { 'virtual' => {'key' => 'name'} }.with_indifferent_access, content:, virtual_parameters: ['my_classification', 'my_classification_two'])
      end
    end

    assert_equal('Two', value[:en])
    assert_equal('Zwei', value[:de])
  end

  it 'should handle emtpy classifications (single)' do
    content = create_content_dummy({
      my_classification: []
    })

    value = subject.concat(virtual_definition: { 'virtual' => {'key' => 'name'} }.with_indifferent_access, content:, virtual_parameters: ['my_classification'])

    assert_nil(value)
  end

  it 'should concat classification aliases of a single classification (multiple)' do
    content = create_content_dummy({
      my_classification:
        create_classification_dummy([{
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One',
          classification_aliases: create_classification_alias_dummy([{
            id: '10000000-0000-0000-0000-000000000001',
            internal_name: 'One',
            name_i18n: {
              en: 'One',
              de: 'Eins'
            }
          }])
        }, {
          id: '00000000-0000-0000-0000-000000000002',
          name: 'Two',
          classification_aliases: create_classification_alias_dummy([{
            id: '10000000-0000-0000-0000-000000000002',
            internal_name: 'Two',
            name_i18n: {
              en: 'Two',
              de: 'Zwei'
            }
          }])
        }])
    })

    value = {}

    [:de, :en].each do |locale|
      I18n.with_locale(locale) do
        value[locale] = subject.concat(virtual_definition: { 'virtual' => {'key' => 'name'} }.with_indifferent_access, content:, virtual_parameters: ['my_classification'])
      end
    end
    assert_equal('One, Two', value[:en])
    assert_equal('Eins, Zwei', value[:de])
  end

  it 'should concat classification aliases of a single classification (single)' do
    content = create_content_dummy({
      my_classification:
        create_classification_dummy([{
          id: '00000000-0000-0000-0000-000000000001',
          name: 'One',
          classification_aliases: create_classification_alias_dummy([{
            id: '10000000-0000-0000-0000-000000000001',
            internal_name: 'One',
            name_i18n: {
              en: 'One',
              de: 'Eins'
            }
          }])
        }])
    })

    value = {}

    [:de, :en].each do |locale|
      I18n.with_locale(locale) do
        value[locale] = subject.concat(virtual_definition: { 'virtual' => {'key' => 'name'} }.with_indifferent_access, content:, virtual_parameters: ['my_classification'])
      end
    end
    assert_equal('One', value[:en])
    assert_equal('Eins', value[:de])
  end
end
