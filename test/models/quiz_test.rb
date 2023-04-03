# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class QuizTest < ActiveSupport::TestCase
    test 'generate a Quiz with questions, then delete all questions and answers' do
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
      assert_equal(13, DataCycleCore::Thing.where(template: false).count)
      assert_equal(16, DataCycleCore::ClassificationContent.count)

      new_data_hash = returned_data_hash # .except("output_channels")
      new_data_hash['question'] = []
      data_set.set_data_hash(data_hash: new_data_hash)
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.where(template: false).count)
      assert_equal(4, DataCycleCore::ClassificationContent.count)
    end

    test 'generate a Quiz with questions and answers, then delete one question' do
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
      assert_equal(13, DataCycleCore::Thing.where(template: false).count)
      assert_equal(16, DataCycleCore::ClassificationContent.count)

      # leave one question alone, delete the second one incl. all related answers and classification_relations
      new_data_hash = returned_data_hash.except('question')
      new_data_hash['question'] = [{ 'id' => returned_data_hash['question'][0]['id'] }]
      data_set.set_data_hash(data_hash: new_data_hash)
      data_set.save

      # check consistency of data in DB
      assert_equal(7, DataCycleCore::Thing.where(template: false).count)
      assert_equal(10, DataCycleCore::ClassificationContent.count)
    end
  end
end
