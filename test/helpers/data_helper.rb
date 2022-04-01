# frozen_string_literal: true

module DataCycleCore
  module DataHelper
    def count_things(diff:)
      before = thing_counts
      yield
      after = thing_counts
      assert_thing_counts(before, after, diff)
    end

    def assert_thing_counts(before, after, diff)
      # puts "#{after} - #{before} °= #{diff}"
      before.zip(after.zip(diff)).map(&:flatten).each do |item|
        assert_equal(item[2], item[1] - item[0])
      end
    end

    private

    def thing_counts
      [
        DataCycleCore::Thing.count,
        DataCycleCore::Thing::History.count,
        DataCycleCore::ContentContent.count,
        DataCycleCore::ContentContent::History.count
      ]
    end
  end
end
