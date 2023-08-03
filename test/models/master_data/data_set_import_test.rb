# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::Templates::TemplateImporter do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::Templates::TemplateImporter
  end

  describe 'loaded template_data' do
    let(:import_path) do
      Rails.root.join('..', 'data_types', 'master_data', 'set_1')
    end

    let(:import_path2) do
      Rails.root.join('..', 'data_types', 'master_data', 'set_2')
    end

    let(:non_existent_path) do
      Rails.root.join('..', 'data_types', '1234567890')
    end

    let(:import_list_import_path) do
      {
        creative_works: [
          {
            name: 'Entity-Creative-Work-1',
            file: import_path.join('creative_works', 'entity.yml').to_s,
            position: 0
          },
          {
            name: 'Entity-Creative-Work-1-1',
            file: import_path.join('creative_works', 'entity.yml').to_s,
            position: 1
          },
          {
            name: 'Entity-Creative-Work-2',
            file: import_path.join('creative_works', 'entity_2.yml').to_s,
            position: 0
          }
        ]
      }
    end

    let(:import_list_import_paths) do
      {
        creative_works: [
          {
            name: 'Entity-Creative-Work-1',
            file: import_path.join('creative_works', 'entity.yml').to_s,
            position: 0
          },
          {
            name: 'Entity-Creative-Work-1-1',
            file: import_path.join('creative_works', 'entity.yml').to_s,
            position: 1
          },
          {
            name: 'Entity-Creative-Work-2',
            file: import_path.join('creative_works', 'entity_2.yml').to_s,
            position: 0
          }
        ]
      }
    end

    let(:duplicates_import_paths) do
      {
        'creative_works.Entity-Creative-Work-1' => [
          import_path2.join('creative_works', 'entity.yml').to_s,
          import_path.join('creative_works', 'entity.yml').to_s
        ]
      }
    end

    it 'gives empty list when wrong path is given for checking duplicates' do
      template_importer = subject.new(template_paths: [non_existent_path])
      assert_equal({}, template_importer.templates)
    end

    it 'gives nil for duplicates when wrong path is given for checking duplicates' do
      template_importer = subject.new(template_paths: [non_existent_path])
      assert_equal({}, template_importer.duplicates)
    end

    it 'gives appropriate list for test_folder' do
      template_importer = subject.new(template_paths: [import_path])
      assert_equal(
        import_list_import_path[:creative_works].pluck(:name),
        template_importer.templates[:creative_works].pluck(:name)
      )
    end

    it 'gives appropriate list for test_folder and test_folder2' do
      template_importer = subject.new(template_paths: [import_path2, import_path])
      assert_equal(
        import_list_import_paths[:creative_works].pluck(:name),
        template_importer.templates[:creative_works].pluck(:name)
      )
    end

    it 'gives appropriate duplicate_list for test_folder and test_folder2' do
      template_importer = subject.new(template_paths: [import_path2, import_path])
      assert_equal duplicates_import_paths, template_importer.duplicates
    end
  end
end
