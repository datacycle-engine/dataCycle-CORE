# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module UserExtensions
    # Coverage for the User filter scopes: date_range / not_date_range (daterange
    # containment) and boolean (truthy/falsy). All run as read-only queries over
    # the seeded users table.
    class FiltersCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::User

      # date_from_filter_object mutates the value (stringify_keys!), so hand it a fresh hash.
      def range
        { 'min' => '2000-01-01', 'max' => '2100-12-31' }
      end

      test 'date_range filters users by a daterange column' do
        assert_kind_of(Array, Subject.date_range(range, 'created_at').to_a)
      end

      test 'not_date_range excludes users within a daterange' do
        assert_kind_of(Array, Subject.not_date_range(range, 'created_at').to_a)
      end

      test 'boolean filters by truthy and falsy values' do
        assert_kind_of(Array, Subject.boolean('true', 'confirmed_at').to_a)
        assert_kind_of(Array, Subject.boolean('false', 'confirmed_at').to_a)
      end
    end
  end
end
