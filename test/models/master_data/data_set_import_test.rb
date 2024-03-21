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

    let(:import_path3) do
      Rails.root.join('..', 'data_types', 'master_data', 'set_3')
    end

    let(:import_path_overlay) do
      Rails.root.join('..', 'data_types', 'master_data', 'overlay_set')
    end

    let(:import_path_overlay2) do
      Rails.root.join('..', 'data_types', 'master_data', 'overlay_set_2')
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

      assert_empty(template_importer.templates)
    end

    it 'gives nil for duplicates when wrong path is given for checking duplicates' do
      template_importer = subject.new(template_paths: [non_existent_path])

      assert_empty(template_importer.duplicates)
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

    it 'extends existing template' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'EntityExtension' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
    end

    it 'overrides existing template' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
    end

    it 'extends multiple existing templates' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity2Extension' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
      assert(template.dig(:data, :properties)&.key?(:text))
    end

    it 'copies overlay flag to all mixin properties' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-3' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:text))
      assert(template.dig(:data, :properties)&.key?(:test_mixin))
      assert(template.dig(:data, :properties, :test_mixin, :overlay))
      assert(template.dig(:data, :properties)&.key?(:test_mixin2))
      assert(template.dig(:data, :properties, :test_mixin2, :overlay))
    end

    it 'change position of propery with after' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'EntityExtension' }

      assert_not(template.nil?)
      assert_equal(template.dig(:data, :properties, :name, :sorting) + 1, template.dig(:data, :properties, :tmp_name, :sorting))
    end

    it 'change position of propery with before' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_not(template.nil?)
      assert_equal(template.dig(:data, :properties, :name, :sorting) - 1, template.dig(:data, :properties, :description, :sorting))
    end

    it 'disable property in all contexts' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties, :name, :xml, :disabled))
      assert(template.dig(:data, :properties, :name, :api, :disabled))
      assert(template.dig(:data, :properties, :name, :ui, :edit, :disabled))
      assert(template.dig(:data, :properties, :name, :ui, :show, :disabled))
    end

    it 'enable property only in xml' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_not(template.nil?)
      assert_not(template.dig(:data, :properties, :description, :xml, :disabled))
      assert(template.dig(:data, :properties, :description, :api, :disabled))
      assert(template.dig(:data, :properties, :description, :ui, :edit, :disabled))
      assert(template.dig(:data, :properties, :description, :ui, :show, :disabled))
    end

    it 'enable property only in api and show' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties, :tmp_name, :xml, :disabled))
      assert_not(template.dig(:data, :properties, :tmp_name, :api, :disabled))
      assert(template.dig(:data, :properties, :tmp_name, :ui, :edit, :disabled))
      assert_not(template.dig(:data, :properties, :tmp_name, :ui, :show, :disabled))
    end

    it 'extend template in same folder' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'EntityExtensionExtension' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:id))
      assert(template.dig(:data, :properties).key?(:name))
      assert(template.dig(:data, :properties).key?(:description))
      assert(template.dig(:data, :properties).key?(:tmp_name))
      assert(template.dig(:data, :properties).key?(:tmp_value))

      assert_equal(template.dig(:data, :properties, :tmp_name, :sorting) - 1, template.dig(:data, :properties, :tmp_value, :sorting))
    end

    it 'overlay for simple attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:name_overlay))
      assert(template.dig(:data, :properties).key?(:name_override))
      assert_not(template.dig(:data, :properties).key?(:name_add))

      assert_equal(template.dig(:data, :properties, :name, :sorting) + 1, template.dig(:data, :properties, :name_override, :sorting))
      assert_equal(template.dig(:data, :properties, :name, :sorting) + 2, template.dig(:data, :properties, :name_overlay, :sorting))

      [:name_overlay, :name_override].each do |key|
        assert_nil(template.dig(:data, :properties, key, :label))
        assert_equal(template.dig(:data, :properties, :name, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :name, :storage_location), template.dig(:data, :properties, key, :storage_location))
        assert_equal(template.dig(:data, :properties, :name, :search), template.dig(:data, :properties, key, :search))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
        assert_not(template.dig(:data, :properties, key).key?(:exif))
        assert_not(template.dig(:data, :properties, key).key?(:content_score))
      end

      assert_equal(template.dig(:data, :properties, :name, :api, :name), template.dig(:data, :properties, :name_overlay, :api, :name))
      assert_equal('none', template.dig(:data, :properties, :name, :ui, :show, :content_area))
      assert_not(template.dig(:data, :properties, :name_overlay, :ui, :show).key?(:content_area))
    end

    it 'overlay for linked attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:author_overlay))
      assert(template.dig(:data, :properties).key?(:author_override))
      assert(template.dig(:data, :properties).key?(:author_add))

      assert_equal(template.dig(:data, :properties, :author, :sorting) + 1, template.dig(:data, :properties, :author_override, :sorting))
      assert_equal(template.dig(:data, :properties, :author, :sorting) + 2, template.dig(:data, :properties, :author_add, :sorting))
      assert_equal(template.dig(:data, :properties, :author, :sorting) + 3, template.dig(:data, :properties, :author_overlay, :sorting))

      [:author_overlay, :author_add, :author_override].each do |key|
        assert_nil(template.dig(:data, :properties, key, :label))
        assert_equal(template.dig(:data, :properties, :author, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :author, :template_name), template.dig(:data, :properties, key, :template_name))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    it 'overlay for classification attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:test_classification_overlay))
      assert(template.dig(:data, :properties).key?(:test_classification_add))

      assert_equal(template.dig(:data, :properties, :test_classification, :sorting) + 1, template.dig(:data, :properties, :test_classification_add, :sorting))
      assert_equal(template.dig(:data, :properties, :test_classification, :sorting) + 2, template.dig(:data, :properties, :test_classification_overlay, :sorting))

      [:test_classification_overlay, :test_classification_add].each do |key|
        assert_nil(template.dig(:data, :properties, key, :label))
        assert_equal(template.dig(:data, :properties, :test_classification, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :test_classification, :tree_label), template.dig(:data, :properties, key, :tree_label))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
        assert_equal(template.dig(:data, :properties, :test_classification, :ui, :show, :content_area), template.dig(:data, :properties, key, :ui, :show, :content_area))
      end
    end

    it 'overlay for opening_time attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_overlay))
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_override))
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_add))

      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 1, template.dig(:data, :properties, :opening_hours_specification_override, :sorting))
      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 2, template.dig(:data, :properties, :opening_hours_specification_add, :sorting))
      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 3, template.dig(:data, :properties, :opening_hours_specification_overlay, :sorting))

      [:opening_hours_specification_overlay, :opening_hours_specification_add, :opening_hours_specification_override].each do |key|
        assert_nil(template.dig(:data, :properties, key, :label))
        assert_equal(template.dig(:data, :properties, :opening_hours_specification, :type), template.dig(:data, :properties, key, :type))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    it 'overlay for schedule attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:event_schedule_overlay))
      assert(template.dig(:data, :properties).key?(:event_schedule_override))
      assert(template.dig(:data, :properties).key?(:event_schedule_add))

      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 1, template.dig(:data, :properties, :event_schedule_override, :sorting))
      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 2, template.dig(:data, :properties, :event_schedule_add, :sorting))
      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 3, template.dig(:data, :properties, :event_schedule_overlay, :sorting))

      [:event_schedule_overlay, :event_schedule_add, :event_schedule_override].each do |key|
        assert_nil(template.dig(:data, :properties, key, :label))
        assert_equal(template.dig(:data, :properties, :event_schedule, :type), template.dig(:data, :properties, key, :type))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    it 'overlay for date attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:start_date_overlay))
      assert(template.dig(:data, :properties).key?(:start_date_override))
      assert_not(template.dig(:data, :properties).key?(:start_date_add))

      assert_equal(template.dig(:data, :properties, :start_date, :sorting) + 1, template.dig(:data, :properties, :start_date_override, :sorting))
      assert_equal(template.dig(:data, :properties, :start_date, :sorting) + 2, template.dig(:data, :properties, :start_date_overlay, :sorting))

      [:start_date_overlay, :start_date_override].each do |key|
        assert_nil(template.dig(:data, :properties, key, :label))
        assert_equal(template.dig(:data, :properties, :start_date, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :start_date, :storage_location), template.dig(:data, :properties, key, :storage_location))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
        assert_not(template.dig(:data, :properties, key).key?(:exif))
        assert_not(template.dig(:data, :properties, key).key?(:content_score))
      end
    end
  end
end
