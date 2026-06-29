# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Filter
    module Common
      # exercises the advanced-attribute query builders mixed into Filter::Search;
      # each builder returns a reflected Filter, and .count validates the generated SQL runs.
      class AdvancedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        UUID = '00000000-0000-0000-0000-000000000001'

        def search
          DataCycleCore::Filter::Search.new(locale: :de)
        end

        test 'advanced_string covers every comparison branch' do
          assert_operator(search.equals_advanced_string({ 'text' => 'a,b' }, 'attr').count, :>=, 0)
          assert_operator(search.not_equals_advanced_string({ 'text' => 'a' }, 'attr').count, :>=, 0)
          assert_operator(search.like_advanced_attributes({ 'text' => 'foo bar' }, 'string', 'attr').count, :>=, 0)
          assert_operator(search.not_like_advanced_attributes({ 'text' => 'foo' }, 'string', 'attr').count, :>=, 0)
          assert_operator(search.exists_advanced_attributes({ 'text' => 'x' }, 'string', 'attr').count, :>=, 0)
          assert_operator(search.not_exists_advanced_attributes({ 'text' => 'x' }, 'string', 'attr').count, :>=, 0)
          # unknown comparison falls through to the else/return-self branch
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_string, { 'text' => 'x' }, 'attr', :unknown))
        end

        test 'advanced_classification_alias_ids covers every comparison branch' do
          assert_operator(search.equals_advanced_classification_alias_ids([UUID], 'attr').count, :>=, 0)
          assert_operator(search.not_equals_advanced_classification_alias_ids([UUID], 'attr').count, :>=, 0)
          assert_operator(search.exists_advanced_classification_alias_ids([UUID], 'attr').count, :>=, 0)
          assert_operator(search.not_exists_advanced_classification_alias_ids([UUID], 'attr').count, :>=, 0)
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_classification_alias_ids, [UUID], 'attr', :unknown))
        end

        test 'advanced_date_range covers equal/not_equal with configured interval keys' do
          value = { 'from' => '2020-01-01', 'until' => '2020-12-31' }
          config = { 'attr' => { 'attribute_keys' => ['from_key', 'to_key'], 'query_operator' => 'overlaps' } }

          DataCycleCore::Feature::AdvancedFilter.stub(:available_advanced_attribute_filters, config) do
            assert_operator(search.equals_advanced_date_range(value, 'attr').count, :>=, 0)
            assert_operator(search.not_equals_advanced_date_range(value, 'attr').count, :>=, 0)
            assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_date_range, value, 'attr', :unknown))
          end
        end

        test 'lower/greater_advanced_attributes dispatch to advanced_time' do
          assert_operator(search.lower_advanced_attributes('12:00', 'time', 'attr').count, :>=, 0)
          assert_operator(search.greater_advanced_attributes('12:00', 'time', 'attr').count, :>=, 0)
        end

        test 'equals_advanced_slug and the numeric/date else branches' do
          assert_operator(search.equals_advanced_slug({ equals: 'some-slug' }).count, :>=, 0)
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_numeric, { 'equals' => '5' }, 'attr', :unknown))
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_date, { 'from' => '2020-01-01' }, 'attr', :unknown))
        end

        test 'translated_name filters build tt_exists subqueries' do
          assert_operator(search.equals_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          assert_operator(search.not_equals_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          assert_operator(search.like_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          assert_operator(search.not_like_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          # exercises the value-nil branch of tt_exists_subquery
          assert_operator(search.exists_advanced_translated_name({ 'text' => 'x' }).count, :>=, 0)
          assert_operator(search.not_exists_advanced_translated_name({ 'text' => 'x' }).count, :>=, 0)
        end
      end
    end
  end
end
