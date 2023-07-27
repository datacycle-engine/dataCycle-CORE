# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class HistoryDeleteTest < ActiveSupport::TestCase
    test 'generate a Quiz with questions, then delete history' do
      cw_temp = DataCycleCore::Thing.count

      # check consistency of data in DB
      assert_equal(0, DataCycleCore::Thing.count - cw_temp)
      assert_equal(0, DataCycleCore::Thing::Translation.count) # - cw_temp (empty translations from Globalize)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      data_hash = {
        'name' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'question' => [
          {
            'name' => 'beliebtestes Handy-OS?',
            'suggested_answer' => [
              { 'text' => 'Android' },
              { 'text' => 'iOS' },
              { 'text' => 'Sailfish' },
              { 'text' => 'Ubuntu Phone' }
            ],
            'accepted_answer' => [
              { 'text' => 'Android' }
            ]
          },
          {
            'name' => 'bestes Desktop OS?',
            'suggested_answer' => [
              { 'text' => 'Linux' },
              { 'text' => 'BSD' },
              { 'text' => 'Windows' },
              { 'text' => 'sonstige' }
            ],
            'accepted_answer' => [
              { 'text' => 'Linux' }
            ]
          }
        ]
      }
      expected_hash_quiz = {
        'name' => 'Dies ist ein Test Quiz!',
        'headline' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!'
      }

      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Quiz', data_hash: data_hash)
      returned_data_hash = data_set.get_data_hash

      assert_equal(0, data_set.errors.messages.size)
      assert_equal(expected_hash_quiz, returned_data_hash.compact.except('question', *DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(2, returned_data_hash['question'].count)
      assert_equal(4, returned_data_hash['question'][0]['suggested_answer'].count)
      assert_equal(4, returned_data_hash['question'][1]['suggested_answer'].count)
      assert_equal(1, returned_data_hash['question'][0]['accepted_answer'].count)
      assert_equal(1, returned_data_hash['question'][1]['accepted_answer'].count)

      # check consistency of data in DB
      assert_equal(13, DataCycleCore::Thing.count - cw_temp)
      assert_equal(13, DataCycleCore::Thing::Translation.count) # - cw_temp (empty translations from Globalize)
      assert_equal(16, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      data_set.set_data_hash(data_hash: data_hash.merge({ 'name' => 'changed Quiz!' }), partial_update: true)

      assert_equal(13, DataCycleCore::Thing.count - cw_temp)
      assert_equal(13, DataCycleCore::Thing::Translation.count) # - cw_temp (empty translations from Globalize)
      assert_equal(16, DataCycleCore::ClassificationContent.count)

      assert_equal(13, DataCycleCore::Thing::History.count)
      assert_equal(13, DataCycleCore::Thing::History::Translation.count)
      assert_equal(16, DataCycleCore::ClassificationContent::History.count)

      data_set.histories.each(&:destroy_content)

      assert_equal(13, DataCycleCore::Thing.count - cw_temp)
      assert_equal(13, DataCycleCore::Thing::Translation.count) # - cw_temp (empty translations from Globalize)
      assert_equal(16, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end

    test 'generate simple Quiz with one question, then delete history' do
      cw_temp = DataCycleCore::Thing.count
      data_set = DataCycleCore::Thing.new(template_name: 'Quiz')
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - cw_temp)
      assert_equal(0, DataCycleCore::Thing::Translation.count) # - cw_temp (empty translations from Globalize)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      data_hash = {
        'name' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'question' => [
          {
            'name' => 'beliebtestes Handy-OS?',
            'suggested_answer' => [],
            'accepted_answer' => []
          }
        ]
      }
      expected_hash_quiz = {
        'name' => 'Dies ist ein Test Quiz!',
        'headline' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!'
      }

      data_set.set_data_hash(data_hash: data_hash, new_content: true)
      returned_data_hash = data_set.get_data_hash

      assert_equal(0, data_set.errors.size)
      assert_equal(expected_hash_quiz, returned_data_hash.compact.except('question', *DataCycleCore::TestPreparations.excepted_attributes('creative_work')).compact)
      assert_equal(data_hash['question'][0], returned_data_hash['question'][0].compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::Thing.count - cw_temp)
      assert_equal(2, DataCycleCore::Thing::Translation.count)  # - cw_temp (empty translations from Globalize)
      assert_equal(5, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      data_set.set_data_hash(data_hash: data_hash.merge({ 'name' => 'changed Quiz!' }), partial_update: true)

      assert_equal(2, DataCycleCore::Thing.count - cw_temp)
      assert_equal(2, DataCycleCore::Thing::Translation.count)  # - cw_temp (empty translations from Globalize)
      assert_equal(5, DataCycleCore::ClassificationContent.count)

      assert_equal(2, DataCycleCore::Thing::History.count)
      assert_equal(2, DataCycleCore::Thing::History::Translation.count)
      assert_equal(5, DataCycleCore::ClassificationContent::History.count)

      data_set.histories.each do |item|
        item.destroy_content
        item.destroy
      end

      assert_equal(2, DataCycleCore::Thing.count - cw_temp)
      assert_equal(2, DataCycleCore::Thing::Translation.count)  # - cw_temp (empty translations from Globalize)
      assert_equal(5, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end
  end
end
