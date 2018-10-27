# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe Hash do
  describe '#with_evaluated_values' do
    describe 'without evaluation markers' do
      it 'should return hash unmodified' do
        hash = {
          one: 1,
          two: 2,
          three: {
            alpha: 'α',
            beta: 'β'
          }
        }

        hash.with_evaluated_values.dig(:one).must_equal 1
        hash.with_evaluated_values.dig(:two).must_equal 2
        hash.with_evaluated_values.dig(:three, :alpha).must_equal 'α'
        hash.with_evaluated_values.dig(:three, :beta).must_equal 'β'
      end
    end

    describe 'with evaluation markers' do
      it 'should return evaluated value' do
        hash = {
          one: 1,
          two: '{{ 1 + 1 }}'
        }

        hash.with_evaluated_values.dig(:one).must_equal 1
        hash.with_evaluated_values.dig(:two).must_equal 2
      end

      it 'should return evaluated value for nested hashes' do
        hash = {
          one: 1,
          two: 2,
          three: {
            value: '{{ Math.sqrt(9) }}'
          }
        }

        hash.with_evaluated_values.dig(:one).must_equal 1
        hash.with_evaluated_values.dig(:two).must_equal 2
        hash.with_evaluated_values.dig(:three, :value).must_equal 3
      end

      it 'should return evaluated value for evaluation markers nested in arrays' do
        hash = {
          array: [
            one: 1,
            two: '{{ 1 + 1 }}'
          ]
        }

        hash.with_evaluated_values[:array][0][:one].must_equal 1
        hash.with_evaluated_values[:array][0][:two].must_equal 2
      end

      it 'should return date based calculations' do
        hash = {
          value: '{{ 3.days.ago.to_date }}'
        }

        hash.with_evaluated_values.dig(:value).must_equal Time.zone.today - 3.days
      end

      it 'should return evaluated values for mongo query' do
        hash = {
          "$or": [
            {
              "dump.de.meta.workflow.state": {
                "$ne": 'published'
              }
            }, {
              "seen_at": {
                "$lt": '{{ 3.days.ago.to_date }}'
              }
            }
          ]
        }

        hash.with_evaluated_values[:$or][1][:seen_at][:$lt].must_equal Time.zone.today - 3.days
      end
    end
  end
end
