# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TemplateImporterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @aggregate_before_state = DataCycleCore.features[:aggregate].deep_dup
      DataCycleCore.features[:aggregate][:enabled] = true
      Feature::Aggregate.reload
    end

    after(:all) do
      DataCycleCore.features = DataCycleCore.features.except(:aggregate).merge({ aggregate: @aggregate_before_state })
      Feature::Aggregate.reload
    end

    test 'gives empty list when wrong path is given for checking duplicates' do
      template_importer = subject.new(template_paths: [non_existent_path])

      assert_empty(template_importer.templates)
    end

    test 'gives nil for duplicates when wrong path is given for checking duplicates' do
      template_importer = subject.new(template_paths: [non_existent_path])

      assert_empty(template_importer.duplicates)
    end

    test 'gives appropriate list for test_folder' do
      template_importer = subject.new(template_paths: [import_path])

      assert_equal(
        import_list_import_path[:creative_works].pluck(:name),
        template_importer.templates[:creative_works].pluck(:name)
      )
    end

    test 'gives appropriate list for test_folder and test_folder2' do
      template_importer = subject.new(template_paths: [import_path2, import_path])

      assert_equal(
        import_list_import_paths[:creative_works].pluck(:name),
        template_importer.templates[:creative_works].pluck(:name)
      )
    end

    test 'gives appropriate duplicate_list for test_folder and test_folder2' do
      template_importer = subject.new(template_paths: [import_path2, import_path])

      assert_equal duplicates_import_paths, template_importer.duplicates
    end

    test 'extends existing template' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'EntityExtension' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
    end

    test 'overrides existing template' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
    end

    test 'extends multiple existing templates' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity2Extension' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
      assert(template.dig(:data, :properties)&.key?(:text))
    end

    test 'copies overlay flag to all mixin properties' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-3' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:text))
      assert(template.dig(:data, :properties)&.key?(:test_mixin))
      assert(template.dig(:data, :properties, :test_mixin, :features, :overlay, :allowed))
      assert(template.dig(:data, :properties)&.key?(:test_mixin2))
      assert(template.dig(:data, :properties, :test_mixin2, :features, :overlay, :allowed))
    end

    test 'change position of propery with after' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'EntityExtension' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_equal(template.dig(:data, :properties, :name, :sorting) + 1, template.dig(:data, :properties, :tmp_name, :sorting))
    end

    test 'change position of propery with before' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_equal(template.dig(:data, :properties, :name, :sorting) - 1, template.dig(:data, :properties, :description, :sorting))
    end

    test 'disable property in all contexts' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties, :name, :xml, :disabled))
      assert(template.dig(:data, :properties, :name, :api, :disabled))
      assert(template.dig(:data, :properties, :name, :ui, :edit, :disabled))
      assert(template.dig(:data, :properties, :name, :ui, :show, :disabled))
    end

    test 'enable property only in xml' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_not(template.dig(:data, :properties, :description, :xml, :disabled))
      assert(template.dig(:data, :properties, :description, :api, :disabled))
      assert(template.dig(:data, :properties, :description, :ui, :edit, :disabled))
      assert(template.dig(:data, :properties, :description, :ui, :show, :disabled))
    end

    test 'enable property only in api and show' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties, :tmp_name, :xml, :disabled))
      assert_not(template.dig(:data, :properties, :tmp_name, :api, :disabled))
      assert(template.dig(:data, :properties, :tmp_name, :ui, :edit, :disabled))
      assert_not(template.dig(:data, :properties, :tmp_name, :ui, :show, :disabled))
    end

    test 'extend template in same folder' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'EntityExtensionExtension' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:id))
      assert(template.dig(:data, :properties).key?(:name))
      assert(template.dig(:data, :properties).key?(:description))
      assert(template.dig(:data, :properties).key?(:tmp_name))
      assert(template.dig(:data, :properties).key?(:tmp_value))

      assert_equal(template.dig(:data, :properties, :tmp_name, :sorting) - 1, template.dig(:data, :properties, :tmp_value, :sorting))
    end

    test 'overlay for simple attribute has correct api name' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay3])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:name_overlay))
      assert(template.dig(:data, :properties).key?(:name_override))
      assert_not(template.dig(:data, :properties).key?(:name_add))
      assert_equal('dc:title', template.dig(:data, :properties, :name, :api, :name))
      assert_equal('dc:title', template.dig(:data, :properties, :name_overlay, :api, :name))
    end

    test 'overlay for simple attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:name_overlay))
      assert(template.dig(:data, :properties).key?(:name_override))
      assert_not(template.dig(:data, :properties).key?(:name_add))
      assert_equal('dc:name', template.dig(:data, :properties, :name, :api, :name))
      assert_equal('dc:name', template.dig(:data, :properties, :name_overlay, :api, :name))

      assert_equal(template.dig(:data, :properties, :name, :sorting) + 1, template.dig(:data, :properties, :name_override, :sorting))
      assert_equal(template.dig(:data, :properties, :name, :sorting) + 2, template.dig(:data, :properties, :name_overlay, :sorting))

      [:name_overlay, :name_override].each do |key|
        assert(template.dig(:data, :properties, key, :label).present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
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

    test 'overlay for linked attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:author_overlay))
      assert(template.dig(:data, :properties).key?(:author_override))
      assert(template.dig(:data, :properties).key?(:author_add))

      assert_equal(template.dig(:data, :properties, :author, :sorting) + 1, template.dig(:data, :properties, :author_override, :sorting))
      assert_equal(template.dig(:data, :properties, :author, :sorting) + 2, template.dig(:data, :properties, :author_add, :sorting))
      assert_equal(template.dig(:data, :properties, :author, :sorting) + 3, template.dig(:data, :properties, :author_overlay, :sorting))

      [:author_overlay, :author_add, :author_override].each do |key|
        assert(template.dig(:data, :properties, key, :label).present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :author, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :author, :template_name), template.dig(:data, :properties, key, :template_name))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    test 'overlay for classification attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:test_classification_overlay))
      assert(template.dig(:data, :properties).key?(:test_classification_add))

      assert_equal(template.dig(:data, :properties, :test_classification, :sorting) + 1, template.dig(:data, :properties, :test_classification_add, :sorting))
      assert_equal(template.dig(:data, :properties, :test_classification, :sorting) + 2, template.dig(:data, :properties, :test_classification_overlay, :sorting))

      [:test_classification_overlay, :test_classification_add].each do |key|
        assert(template.dig(:data, :properties, key, :label).present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :test_classification, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :test_classification, :tree_label), template.dig(:data, :properties, key, :tree_label))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
        assert_equal(template.dig(:data, :properties, :test_classification, :ui, :show, :content_area), template.dig(:data, :properties, key, :ui, :show, :content_area))
      end
    end

    test 'overlay for opening_time attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_overlay))
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_override))
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_add))

      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 1, template.dig(:data, :properties, :opening_hours_specification_override, :sorting))
      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 2, template.dig(:data, :properties, :opening_hours_specification_add, :sorting))
      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 3, template.dig(:data, :properties, :opening_hours_specification_overlay, :sorting))

      [:opening_hours_specification_overlay, :opening_hours_specification_add, :opening_hours_specification_override].each do |key|
        assert(template.dig(:data, :properties, key, :label).present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :opening_hours_specification, :type), template.dig(:data, :properties, key, :type))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    test 'overlay for schedule attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:event_schedule_overlay))
      assert(template.dig(:data, :properties).key?(:event_schedule_override))
      assert(template.dig(:data, :properties).key?(:event_schedule_add))

      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 1, template.dig(:data, :properties, :event_schedule_override, :sorting))
      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 2, template.dig(:data, :properties, :event_schedule_add, :sorting))
      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 3, template.dig(:data, :properties, :event_schedule_overlay, :sorting))

      [:event_schedule_overlay, :event_schedule_add, :event_schedule_override].each do |key|
        assert(template.dig(:data, :properties, key, :label).present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :event_schedule, :type), template.dig(:data, :properties, key, :type))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    test 'overlay for date attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:start_date_overlay))
      assert(template.dig(:data, :properties).key?(:start_date_override))
      assert_not(template.dig(:data, :properties).key?(:start_date_add))

      assert_equal(template.dig(:data, :properties, :start_date, :sorting) + 1, template.dig(:data, :properties, :start_date_override, :sorting))
      assert_equal(template.dig(:data, :properties, :start_date, :sorting) + 2, template.dig(:data, :properties, :start_date_overlay, :sorting))

      [:start_date_overlay, :start_date_override].each do |key|
        assert(template.dig(:data, :properties, key, :label).present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :start_date, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :start_date, :storage_location), template.dig(:data, :properties, key, :storage_location))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
        assert_not(template.dig(:data, :properties, key).key?(:exif))
        assert_not(template.dig(:data, :properties, key).key?(:content_score))
      end
    end

    test 'aggregate template with correct definitions' do
      template_importer = subject.new(template_paths: [import_path, import_path4])
      template_name = 'Entity-With-Aggregate-Creative-Work-1'
      agg_template_name = MasterData::Templates::AggregateTemplate.aggregate_template_name(template_name)
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == template_name }
      agg_template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == agg_template_name }

      assert_empty(template_importer.errors)
      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_not(agg_template.nil?)
      assert_equal(
        [template_name, *template.dig(:data, 'features', 'aggregate', MasterData::Templates::AggregateTemplate::ADDITIONAL_BASE_TEMPLATES_KEY)],
        agg_template.dig(:data, 'properties', MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME, 'template_name')
      )
      assert_equal(
        [template_name, *template.dig(:data, 'features', 'aggregate', MasterData::Templates::AggregateTemplate::ADDITIONAL_BASE_TEMPLATES_KEY)],
        agg_template.dig(:data, 'properties', DataCycleCore::MasterData::Templates::AggregateTemplate.aggregate_property_key('name'), 'template_name')
      )

      assert(agg_template.dig(:data, :properties).key?(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME))
      assert(agg_template.dig(:data, :properties).key?(:id))
      assert(template.dig(:data, :properties).key?(MasterData::Templates::AggregateTemplate::AGGREGATE_INVERSE_PROPERTY_NAME))
      assert(template.dig(:data, :properties, MasterData::Templates::AggregateTemplate::AGGREGATE_INVERSE_PROPERTY_NAME).key?(:sorting))

      template.dig(:data, :properties).each do |key, old_prop|
        next unless DataCycleCore::MasterData::Templates::AggregateTemplate.key_allowed_for_aggregate?(key:, prop: old_prop)

        prop = agg_template.dig(:data, :properties, key)
        assert_not(prop.nil?)
        assert(prop.key?(:compute))
        sorting = prop[:sorting]

        agg_prop = agg_template.dig(:data, :properties, DataCycleCore::MasterData::Templates::AggregateTemplate.aggregate_property_key(key))
        assert_not(agg_prop.nil?)
        assert_equal(sorting - 1, agg_prop[:sorting])
        assert_equal('linked', agg_prop[:type])

        assert(agg_template.dig(:data, :properties).key?("#{key}_overlay"))
        assert_equal(sorting + 2, agg_template.dig(:data, :properties, "#{key}_overlay", :sorting))

        DataCycleCore::MasterData::Templates::Extensions::Overlay.allowed_postfixes_for_type(prop[:type]).each.with_index(1) do |k, index|
          assert(agg_template.dig(:data, :properties).key?("#{key}#{k}"))
          assert_equal(sorting + index, agg_template.dig(:data, :properties, "#{key}#{k}", :sorting))
        end
      end
    end

    test 'imports correct template when overwriting it from another folder' do
      template_importer = subject.new(template_paths: [import_path2, import_path5])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert_not(template.dig(:data, :properties)&.key?(:description))
      assert_equal('Name', template.dig(:data, :properties, :name, :label))
    end

    test 'imports correct template when overwriting it from another folder in reverse order' do
      template_importer = subject.new(template_paths: [import_path5, import_path2])
      template = template_importer.templates.dig(:creative_works).find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert_equal('Titel', template.dig(:data, :properties, :name, :label))
    end

    private

    def subject
      DataCycleCore::MasterData::Templates::TemplateImporter
    end

    def import_path
      Rails.root.join('..', 'data_types', 'master_data', 'set_1')
    end

    def import_path2
      Rails.root.join('..', 'data_types', 'master_data', 'set_2')
    end

    def import_path3
      Rails.root.join('..', 'data_types', 'master_data', 'set_3')
    end

    def import_path4
      Rails.root.join('..', 'data_types', 'master_data', 'set_4')
    end

    def import_path5
      Rails.root.join('..', 'data_types', 'master_data', 'set_5')
    end

    def import_path_overlay
      Rails.root.join('..', 'data_types', 'master_data', 'overlay_set')
    end

    def import_path_overlay2
      Rails.root.join('..', 'data_types', 'master_data', 'overlay_set_2')
    end

    def import_path_overlay3
      Rails.root.join('..', 'data_types', 'master_data', 'overlay_set_3')
    end

    def non_existent_path
      Rails.root.join('..', 'data_types', '1234567890')
    end

    def import_list_import_path
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

    def import_list_import_paths
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

    def duplicates_import_paths
      {
        'creative_works.Entity-Creative-Work-1' => [
          import_path2.join('creative_works', 'entity.yml').to_s,
          import_path.join('creative_works', 'entity.yml').to_s
        ]
      }
    end
  end
end
