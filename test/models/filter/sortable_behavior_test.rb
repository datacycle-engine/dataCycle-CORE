# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SortableBehaviorTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @now = Time.zone.now
      @event_a = create_event('Sortable Event A', @now + 1.hour)
      @event_b = create_event('Sortable Event B', @now + 25.hours)
      @event_c = create_event('Sortable Event C', @now + 73.hours)
      @event_d = create_event('Sortable Event D', @now + 10.days)
      @article = create_content('Artikel', { name: 'Gipfelwanderung Dolomiten' })
      @article_match = create_content('Artikel', { name: 'Wolfgangsee Ruderboot Verleih' })
    end

    def create_event(name, start_time)
      create_content('Event', {
        name:,
        event_schedule: [{
          'start_time' => {
            'time' => start_time.iso8601,
            'zone' => 'Europe/Vienna'
          },
          'rtimes' => [],
          'duration' => 1.hour.to_i,
          'rrules' => nil
        }]
      })
    end

    def search_for(*contents)
      DataCycleCore::Filter::Search.new(locale: ['de']).where(id: contents.map(&:id))
    end

    def occurrence_range
      {
        'min' => @now.beginning_of_day.iso8601,
        'max' => (@now + 5.days).end_of_day.iso8601
      }
    end

    def sorted_ids(search)
      search.query.pluck(:id)
    end

    test 'sort_proximity_in_time orders events by proximity to now by default' do
      result = search_for(@event_b, @event_c, @event_a).sort_proximity_in_time

      assert_equal([@event_a.id, @event_b.id, @event_c.id], sorted_ids(result))
    end

    test 'sort_proximity_in_time orders events by proximity to given date' do
      result = search_for(@event_a, @event_b, @event_c).sort_proximity_in_time('', { 'in' => { 'min' => (@now + 72.hours).iso8601 } })

      assert_equal([@event_c.id, @event_b.id, @event_a.id], sorted_ids(result))
    end

    test 'sort_proximity_in_time orders events by proximity to relative date' do
      result = search_for(@event_a, @event_b, @event_c).sort_proximity_in_time('', { 'q' => 'relative', 'v' => { 'from' => { 'n' => '3', 'unit' => 'day', 'mode' => 'p' } } })

      assert_equal([@event_c.id, @event_b.id, @event_a.id], sorted_ids(result))
    end

    test 'sort_by_proximity orders events by next occurrence with nulls last' do
      result = search_for(@event_b, @article, @event_c, @event_a).sort_by_proximity('ASC', { 'in' => occurrence_range })

      assert_equal([@event_a.id, @event_b.id, @event_c.id, @article.id], sorted_ids(result))

      result = search_for(@event_b, @article, @event_c, @event_a).sort_by_proximity('DESC', { 'in' => occurrence_range })

      assert_equal([@event_c.id, @event_b.id, @event_a.id, @article.id], sorted_ids(result))
    end

    test 'sort_proximity_in_occurrence orders events by occurrence in range with nulls last' do
      result = search_for(@event_b, @article, @event_c, @event_a).sort_proximity_in_occurrence('ASC', { 'in' => occurrence_range })

      assert_equal([@event_a.id, @event_b.id, @event_c.id, @article.id], sorted_ids(result))

      result = search_for(@event_b, @article, @event_c, @event_a).sort_proximity_in_occurrence('DESC', { 'in' => occurrence_range })

      assert_equal([@event_c.id, @event_b.id, @event_a.id, @article.id], sorted_ids(result))
    end

    test 'sort_proximity_occurrence_with_distance orders events by occurrence in range with nulls last' do
      result = search_for(@event_b, @article, @event_c, @event_a).sort_proximity_occurrence_with_distance('ASC', [['10', '47'], { 'in' => occurrence_range }])

      assert_equal([@event_a.id, @event_b.id, @event_c.id, @article.id], sorted_ids(result))
    end

    test 'sort_proximity_in_occurrence_with_distance sorts things with occurrences before things without' do
      result = search_for(@event_b, @article, @event_a).sort_proximity_in_occurrence_with_distance('ASC', [['10', '47'], { 'in' => occurrence_range }])
      ids = sorted_ids(result)

      assert_equal([@event_a.id, @event_b.id].sort, ids.first(2).sort)
      assert_equal(@article.id, ids.last)
    end

    test 'sort_proximity_in_occurrence_with_distance_pia orders by occurrence category' do
      contents = [@event_d, @article, @event_c, @event_a, @event_b]
      value = [['10', '47'], { 'in' => occurrence_range, 'relation' => 'eventSchedule' }]
      in_range_ids = [@event_b.id, @event_c.id].sort

      # category 1: occurrence today (A), category 2: occurrence in range (B, C),
      # category 3: occurrence outside range (D), NULLS LAST: no occurrence at all (article)
      ids = sorted_ids(search_for(*contents).sort_proximity_in_occurrence_with_distance_pia('ASC', value))

      assert_equal(@event_a.id, ids.first)
      assert_equal(in_range_ids, ids[1..2].sort)
      assert_equal([@event_d.id, @article.id], ids.last(2))

      ids = sorted_ids(search_for(*contents).sort_proximity_in_occurrence_with_distance_pia('DESC', value))

      assert_equal(@event_d.id, ids.first)
      assert_equal(in_range_ids, ids[1..2].sort)
      assert_equal([@event_a.id, @article.id], ids.last(2))
    end

    test 'sort_legacy_fulltext_search orders by relevance' do
      result = search_for(@article, @article_match).sort_legacy_fulltext_search('DESC', 'Wolfgangsee Ruderboot')

      assert_equal([@article_match.id, @article.id], sorted_ids(result))

      result = search_for(@article, @article_match).sort_legacy_fulltext_search('ASC', 'Wolfgangsee Ruderboot')

      assert_equal([@article.id, @article_match.id], sorted_ids(result))
    end

    test 'sort_ts_rank_fulltext_search orders by ts_rank relevance' do
      result = search_for(@article, @article_match).sort_ts_rank_fulltext_search('DESC', { value: 'Wolfgangsee Ruderboot', fields: nil })

      assert_equal([@article_match.id, @article.id], sorted_ids(result))

      result = search_for(@article, @article_match).sort_ts_rank_fulltext_search('ASC', 'Wolfgangsee Ruderboot')

      assert_equal([@article.id, @article_match.id], sorted_ids(result))
    end
  end
end
