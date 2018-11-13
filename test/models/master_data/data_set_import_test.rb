# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ImportTemplates do
  subject do
    DataCycleCore::MasterData::ImportTemplates
  end

  describe 'loaded template_data' do
    let(:import_path) do
      Rails.root.join('..', 'data_types', 'test_folder')
    end

    let(:import_path2) do
      Rails.root.join('..', 'data_types', 'test_folder2')
    end

    let(:non_existent_path) do
      Rails.root.join('..', 'data_types', '1234567890')
    end

    let(:import_list_import_path) do
      {
        creative_works: [
          {
            name: 'Bild2',
            file: import_path.join('creative_works', 'bild2_test.yml').to_s,
            position: 0
          },
          {
            name: 'BildMinimal',
            file: import_path.join('creative_works', 'bild2_test.yml').to_s,
            position: 1
          }
        ]
      }
    end

    let(:import_list_import_paths) do
      {
        creative_works: [
          {
            name: 'BildMinimal',
            file: import_path.join('creative_works', 'bild2_test.yml').to_s,
            position: 1
          },
          {
            name: 'Bild2',
            file: import_path.join('creative_works', 'bild2_test.yml').to_s,
            position: 0
          }
        ]
      }
    end

    let(:duplicates_import_paths) do
      {
        creative_works: {
          'BildMinimal' => [
            {
              file: import_path2.join('creative_works', 'bild2_test.yml').to_s,
              position: 0
            },
            {
              file: import_path.join('creative_works', 'bild2_test.yml').to_s,
              position: 1
            }
          ]
        }
      }
    end

    it 'gives empty list when wrong path is given for checking duplicates' do
      import_list, _duplicates = subject.check_for_duplicates([non_existent_path], ['things'])
      assert_equal DataCycleCore.content_tables.map { |item| { item.to_sym => [] } }.inject(&:merge), import_list
    end

    it 'gives nil for duplicates when wrong path is given for checking duplicates' do
      _import_list, duplicates = subject.check_for_duplicates([non_existent_path], ['things'])
      assert_nil duplicates
    end

    it 'gives appropriate list for test_folder' do
      import_list, _duplicates = subject.check_for_duplicates([import_path], ['creative_works'])
      assert_equal import_list_import_path, import_list
    end

    it 'gives appropriate list for test_folder and test_folder2' do
      import_list, _duplicates = subject.check_for_duplicates([import_path2, import_path], ['creative_works'])
      assert_equal import_list_import_paths, import_list
    end

    it 'gives appropriate duplicate_list for test_folder and test_folder2' do
      _import_list, duplicates = subject.check_for_duplicates([import_path2, import_path], ['creative_works'])
      assert_equal duplicates_import_paths, duplicates
    end
  end
end
