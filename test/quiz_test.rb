require 'test_helper'

module DataCycleCore
  class QuizTest < ActiveSupport::TestCase
    test 'CreativeWork exists' do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
    end

    test 'generate a Quiz with questions, then delete all questions and answers' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Quiz')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'question' => [
          {
            'headline' => 'beliebtestes Handy-OS?',
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
            'headline' => 'bestes Desktop OS?',
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
        'kind' => [],
        'tags' => [],
        'state' => [],
        'season' => [],
        'topics' => [],
        'markets' => [],
        'headline' => 'Dies ist ein Test Quiz!',
        'output_channels' => [],
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'permitted_creator' => []
      }

      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash_quiz, returned_data_hash.except('question', 'id', 'data_type', 'validity_period', 'data_pool').compact)
      assert_equal(2, returned_data_hash['question'].count)
      assert_equal(4, returned_data_hash['question'][0]['suggested_answer'].count)
      assert_equal(4, returned_data_hash['question'][1]['suggested_answer'].count)
      assert_equal(1, returned_data_hash['question'][0]['accepted_answer'].count)
      assert_equal(1, returned_data_hash['question'][1]['accepted_answer'].count)

      # check consistency of data in DB
      assert_equal(13, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(14, DataCycleCore::ClassificationContent.count)

      new_data_hash = returned_data_hash # .except("output_channels")
      new_data_hash['question'] = []
      error = data_set.set_data_hash(data_hash: new_data_hash)
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
    end

    test 'generate a Quiz with questions and answers, then delete one question' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Quiz')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'question' => [
          {
            'headline' => 'beliebtestes Handy-OS?',
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
            'headline' => 'bestes Desktop OS?',
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
        'kind' => [],
        'tags' => [],
        'state' => [],
        'season' => [],
        'topics' => [],
        'creator' => [],
        'markets' => [],
        'headline' => 'Dies ist ein Test Quiz!',
        'output_channels' => [],
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'permitted_creator' => []
      }

      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash

      assert_equal(0, error[:error].count)
      assert_equal(expected_hash_quiz, returned_data_hash.except('question', 'id', 'data_type', 'validity_period', 'data_pool').compact)
      assert_equal(2, returned_data_hash['question'].count)
      assert_equal(4, returned_data_hash['question'][0]['suggested_answer'].count)
      assert_equal(4, returned_data_hash['question'][1]['suggested_answer'].count)
      assert_equal(1, returned_data_hash['question'][0]['accepted_answer'].count)
      assert_equal(1, returned_data_hash['question'][1]['accepted_answer'].count)

      # check consistency of data in DB
      assert_equal(13, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(14, DataCycleCore::ClassificationContent.count)

      # leave one question alone, delete the second one incl. all related answers and classification_relations
      new_data_hash = returned_data_hash.except('question')
      new_data_hash['question'] = [{ 'id' => returned_data_hash['question'][0]['id'] }]
      error = data_set.set_data_hash(data_hash: new_data_hash)
      data_set.save

      # check consistency of data in DB
      assert_equal(7, DataCycleCore::CreativeWork.where(template: false).count)
      assert_equal(8, DataCycleCore::ClassificationContent.count)
    end
  end
end
