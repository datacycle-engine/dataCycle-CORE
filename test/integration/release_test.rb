require 'test_helper'

module DataCycleCore
  class ReleaseTest < ActiveSupport::TestCase
    test 'save CreativeWork data-type ReleaseTest' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'ReleaseTest')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'description' => 'description',
        'description2' => 'description2'
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      assert_equal(data_hash, data_set.get_data_hash.compact)
    end

    test 'save CreativeWork data-type ReleaseTest with status' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'ReleaseTest')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save

      release_id = DataCycleCore::Release.find_by(release_code: 10).id

      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'description' => {
          'value' => 'description',
          'release_id' => release_id,
          'release_comment' => 'noch nicht fertig'
        },
        'description2' => 'description2'
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save

      assert_equal(data_hash, data_set.get_data_hash)
      assert_equal(release_id, data_set.release_id)
    end

    test 'save releasable embeddedObjects (Artikel/Zitat)' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save

      template_bild = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild')

      bild1 = DataCycleCore::CreativeWork.new
      bild1.schema = template_bild.schema
      bild1.template_name = template_bild.template_name
      bild1.save
      bild1.set_data_hash(data_hash: { 'headline' => 'Testbild1' })
      bild1.save

      bild2 = DataCycleCore::CreativeWork.new
      bild2.schema = template_bild.schema
      bild2.template_name = template_bild.template_name
      bild2.save
      bild2.set_data_hash(data_hash: { 'headline' => 'Testbild2' })
      bild2.save

      data_hash = {
        'kind' => [],
        'tags' => [],
        'creator' => [],
        'image' => {
          'value' => [bild1.id],
          'release_id' => DataCycleCore::Release.first.id,
          'release_comment' => 'normales bild kommentar'
        },
        'state' => [],
        'video' => [],
        'season' => [],
        'topics' => [],
        'markets' => [],
        'headline' => 'Release Artikel 15',
        'quotation' => [{
          'text' => '<p>sdfasf asdf adfasdf</p>',
          'image' => {
            'value' => [bild2.id],
            'release_id' => DataCycleCore::Release.second.id,
            'release_comment' => 'zitat bild kommentar'
          },
          'author' => [],
          'creator' => []
        }],
        'output_channels' => [],
        'content_location' => [],
        'permitted_creator' => []
      }

      set_hash = data_hash.deep_dup

      error = data_set.set_data_hash(data_hash: set_hash)
      data_set.save

      expected_data_hash = data_hash.deep_dup
      expected_data_hash['image']['value'] = DataCycleCore::CreativeWork.where(id: bild1.id)
      expected_data_hash['quotation'].first['image']['value'] = DataCycleCore::CreativeWork.where(id: bild2.id)

      returned_data_hash = data_set.get_data_hash
      assert_equal(expected_data_hash.except('quotation', 'image'), returned_data_hash.compact.except('id', 'data_type', 'quotation', 'data_pool', 'image'))
      assert_equal(expected_data_hash['image'].except('value'), returned_data_hash['image'].except('value'))
      assert_equal(bild1.id, returned_data_hash['image']['value'].ids.first)
      assert_equal(expected_data_hash['quotation'][0].except('image'), returned_data_hash['quotation'][0].compact.except('id', 'data_type', 'is_part_of', 'image'))
      assert_equal(expected_data_hash['quotation'][0]['image'].except('value'), returned_data_hash['quotation'][0]['image'].except('value'))
      assert_equal(bild2.id, returned_data_hash['quotation'][0]['image']['value'].ids.first)

      expected_release_main_object = {
        'image' => {
          'release_id' => DataCycleCore::Release.first.id,
          'release_comment' => 'normales bild kommentar'
        }
      }
      assert_equal(expected_release_main_object, data_set.release)

      expected_release_quotation = {
        'image' => {
          'release_id' => DataCycleCore::Release.second.id,
          'release_comment' => 'zitat bild kommentar'
        }
      }
      assert_equal(expected_release_quotation, DataCycleCore::CreativeWork.find(returned_data_hash['quotation'][0]['id']).release)

      expected_release_code = [DataCycleCore::Release.first.release_code, DataCycleCore::Release.second.release_code].max
      assert_equal(expected_release_code, data_set.release_status_code)
    end
  end
end
