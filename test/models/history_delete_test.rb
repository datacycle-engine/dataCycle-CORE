# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class HistoryDeleteTest < ActiveSupport::TestCase
    test 'generate a Quiz with questions, then delete history' do
      cw_temp = DataCycleCore::CreativeWork.count
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Quiz')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)

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
      assert_equal(13, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(13, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(14, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)

      data_set.set_data_hash(data_hash: data_hash.merge({ 'headline' => 'changed Quiz!' }))
      data_set.save

      assert_equal(13, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(13, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(14, DataCycleCore::ClassificationContent.count)

      assert_equal(14, DataCycleCore::CreativeWork::History.count)
      assert_equal(14, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(14, DataCycleCore::ClassificationContent::History.count)

      data_set.histories.each do |item|
        item.destroy_content
        item.destroy
      end

      assert_equal(13, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(13, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(14, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end

    test 'generate simple Quiz with one question, then delete history' do
      cw_temp = DataCycleCore::CreativeWork.count
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Quiz')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)

      data_hash = {
        'headline' => 'Dies ist ein Test Quiz!',
        'alternative_headline' => 'ein lustiges Quiz für jeden Tag!',
        'question' => [
          {
            'headline' => 'beliebtestes Handy-OS?',
            'suggested_answer' => [],
            'accepted_answer' => []
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
      assert_equal(data_hash['question'][0], returned_data_hash['question'][0].except('id', 'data_type', 'image', 'creator').compact)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)

      data_set.set_data_hash(data_hash: data_hash.merge({ 'headline' => 'changed Quiz!' }))
      data_set.save

      assert_equal(2, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(3, DataCycleCore::ClassificationContent.count)

      assert_equal(3, DataCycleCore::CreativeWork::History.count)
      assert_equal(3, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(3, DataCycleCore::ClassificationContent::History.count)

      data_set.histories.each do |item|
        item.destroy_content
        item.destroy
      end

      assert_equal(2, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - cw_temp)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end
  end
end