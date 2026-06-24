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

    test 'gives error for non existing templates in template_name definition' do
      template_importer = subject.new(template_paths: [import_path_missing_template])
      errors = template_importer.validate

      assert_equal(1, errors.count)
      assert_equal("creative_works.MissingTemplateDummy1.data.properties.linked_entity.template_name => template for 'NonExistingTemplate' missing!", errors.first)
    end

    test 'gives appropriate list for test_folder' do
      template_importer = subject.new(template_paths: [import_path])

      assert_equal(
        expected_templates_for_single_path.pluck(:name),
        template_importer.templates.pluck(:name)
      )
    end

    test 'gives appropriate list for test_folder and test_folder2' do
      template_importer = subject.new(template_paths: [import_path2, import_path])

      assert_equal(
        expected_templates_for_multiple_paths.pluck(:name),
        template_importer.templates.pluck(:name)
      )
    end

    test 'gives appropriate duplicate_list for test_folder and test_folder2' do
      template_importer = subject.new(template_paths: [import_path2, import_path])

      assert_equal expected_template_duplicates, template_importer.duplicates
    end

    test 'extends existing template' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'EntityExtension' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
    end

    test 'overrides existing template' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert(template.dig(:data, :properties)&.key?(:tmp_name))
    end

    test 'extends multiple existing templates' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'Entity2Extension' }

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
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-3' }

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
      template = template_importer.templates.find { |t| t[:name] == 'EntityExtension' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_equal(template.dig(:data, :properties, :name, :sorting) + 1, template.dig(:data, :properties, :tmp_name, :sorting))
    end

    test 'change position of propery with before' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_equal(template.dig(:data, :properties, :name, :sorting) - 1, template.dig(:data, :properties, :description, :sorting))
    end

    test 'disable property in all contexts' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties, :name, :xml, :disabled))
      assert(template.dig(:data, :properties, :name, :api, :disabled))
      assert(template.dig(:data, :properties, :name, :ui, :edit, :disabled))
      assert(template.dig(:data, :properties, :name, :ui, :show, :disabled))
    end

    test 'enable property only in xml' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_not(template.dig(:data, :properties, :description, :xml, :disabled))
      assert(template.dig(:data, :properties, :description, :api, :disabled))
      assert(template.dig(:data, :properties, :description, :ui, :edit, :disabled))
      assert(template.dig(:data, :properties, :description, :ui, :show, :disabled))
    end

    test 'enable property only in api and show' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties, :tmp_name, :xml, :disabled))
      assert_not(template.dig(:data, :properties, :tmp_name, :api, :disabled))
      assert(template.dig(:data, :properties, :tmp_name, :ui, :edit, :disabled))
      assert_not(template.dig(:data, :properties, :tmp_name, :ui, :show, :disabled))
    end

    test 'extend template in same folder' do
      template_importer = subject.new(template_paths: [import_path2, import_path3])
      template = template_importer.templates.find { |t| t[:name] == 'EntityExtensionExtension' }

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
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

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
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

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
        assert_predicate(template.dig(:data, :properties, key, :label), :present?)
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
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:author_overlay))
      assert(template.dig(:data, :properties).key?(:author_override))
      assert(template.dig(:data, :properties).key?(:author_add))

      assert_equal(template.dig(:data, :properties, :author, :sorting) + 1, template.dig(:data, :properties, :author_override, :sorting))
      assert_equal(template.dig(:data, :properties, :author, :sorting) + 2, template.dig(:data, :properties, :author_add, :sorting))
      assert_equal(template.dig(:data, :properties, :author, :sorting) + 3, template.dig(:data, :properties, :author_overlay, :sorting))

      [:author_overlay, :author_add, :author_override].each do |key|
        assert_predicate(template.dig(:data, :properties, key, :label), :present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :author, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :author, :template_name), template.dig(:data, :properties, key, :template_name))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    test 'overlay for classification attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:test_classification_overlay))
      assert(template.dig(:data, :properties).key?(:test_classification_add))

      assert_equal(template.dig(:data, :properties, :test_classification, :sorting) + 1, template.dig(:data, :properties, :test_classification_add, :sorting))
      assert_equal(template.dig(:data, :properties, :test_classification, :sorting) + 2, template.dig(:data, :properties, :test_classification_overlay, :sorting))

      [:test_classification_overlay, :test_classification_add].each do |key|
        assert_predicate(template.dig(:data, :properties, key, :label), :present?)
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
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_overlay))
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_override))
      assert(template.dig(:data, :properties).key?(:opening_hours_specification_add))

      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 1, template.dig(:data, :properties, :opening_hours_specification_override, :sorting))
      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 2, template.dig(:data, :properties, :opening_hours_specification_add, :sorting))
      assert_equal(template.dig(:data, :properties, :opening_hours_specification, :sorting) + 3, template.dig(:data, :properties, :opening_hours_specification_overlay, :sorting))

      [:opening_hours_specification_overlay, :opening_hours_specification_add, :opening_hours_specification_override].each do |key|
        assert_predicate(template.dig(:data, :properties, key, :label), :present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :opening_hours_specification, :type), template.dig(:data, :properties, key, :type))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    test 'overlay for schedule attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:event_schedule_overlay))
      assert(template.dig(:data, :properties).key?(:event_schedule_override))
      assert(template.dig(:data, :properties).key?(:event_schedule_add))

      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 1, template.dig(:data, :properties, :event_schedule_override, :sorting))
      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 2, template.dig(:data, :properties, :event_schedule_add, :sorting))
      assert_equal(template.dig(:data, :properties, :event_schedule, :sorting) + 3, template.dig(:data, :properties, :event_schedule_overlay, :sorting))

      [:event_schedule_overlay, :event_schedule_add, :event_schedule_override].each do |key|
        assert_predicate(template.dig(:data, :properties, key, :label), :present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :event_schedule, :type), template.dig(:data, :properties, key, :type))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
      end
    end

    test 'overlay for date attribute' do
      template_importer = subject.new(template_paths: [import_path_overlay, import_path_overlay2])
      template = template_importer.templates.find { |t| t[:name] == 'TestOverlay' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties).key?(:start_date_overlay))
      assert(template.dig(:data, :properties).key?(:start_date_override))
      assert_not(template.dig(:data, :properties).key?(:start_date_add))

      assert_equal(template.dig(:data, :properties, :start_date, :sorting) + 1, template.dig(:data, :properties, :start_date_override, :sorting))
      assert_equal(template.dig(:data, :properties, :start_date, :sorting) + 2, template.dig(:data, :properties, :start_date_overlay, :sorting))

      [:start_date_overlay, :start_date_override].each do |key|
        assert_predicate(template.dig(:data, :properties, key, :label), :present?)
        assert(template.dig(:data, :properties, key, :label).is_a?(::Hash))
        assert_equal(template.dig(:data, :properties, :start_date, :type), template.dig(:data, :properties, key, :type))
        assert_equal(template.dig(:data, :properties, :start_date, :storage_location), template.dig(:data, :properties, key, :storage_location))
        assert_not(template.dig(:data, :properties, key).key?(:validations))
        assert(template.dig(:data, :properties, key, :local))
        assert_not(template.dig(:data, :properties, key).key?(:exif))
        assert_not(template.dig(:data, :properties, key).key?(:content_score))
      end
    end

    test 'aggregate templates with correct belongs_to_aggregate definitions' do
      template_importer = subject.new(template_paths: [import_path, import_path4, aggregate_path1])
      template_names = ['Entity-With-Aggregate-Creative-Work-1', 'Entity-With-Aggregate-Creative-Work-2']
      agg_template_names = template_names.map { |tn| MasterData::Templates::AggregateTemplate.aggregate_template_name(tn) }
      agg_templates = template_importer.templates.select { |t| t[:name].in?(agg_template_names) }
      additional_base_template1 = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }
      additional_base_template2 = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-2' }

      assert_equal(
        agg_templates.pluck(:name),
        additional_base_template1.dig(:data, :properties, MasterData::Templates::AggregateTemplate::AGGREGATE_INVERSE_PROPERTY_NAME, :template_name)
      )

      assert_equal(
        agg_templates.pluck(:name),
        additional_base_template2.dig(:data, :properties, MasterData::Templates::AggregateTemplate::AGGREGATE_INVERSE_PROPERTY_NAME, :template_name)
      )
    end

    test 'aggregate template with correct definitions' do
      template_importer = subject.new(template_paths: [import_path, import_path4])
      template_name = 'Entity-With-Aggregate-Creative-Work-1'
      agg_template_name = MasterData::Templates::AggregateTemplate.aggregate_template_name(template_name)
      template = template_importer.templates.find { |t| t[:name] == template_name }
      agg_template = template_importer.templates.find { |t| t[:name] == agg_template_name }
      additional_base_template1 = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }
      additional_base_template2 = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-2' }

      assert_empty(template_importer.errors)
      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert_not(agg_template.nil?)

      assert_equal(
        agg_template[:name],
        additional_base_template1.dig(:data, :properties, MasterData::Templates::AggregateTemplate::AGGREGATE_INVERSE_PROPERTY_NAME, :template_name)
      )

      assert_equal(
        agg_template[:name],
        additional_base_template2.dig(:data, :properties, MasterData::Templates::AggregateTemplate::AGGREGATE_INVERSE_PROPERTY_NAME, :template_name)
      )

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
        next if old_prop[:type] == 'linked' && old_prop[:link_direction] == 'inverse'

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
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert_not(template.dig(:data, :properties)&.key?(:description))
      assert_equal('Name', template.dig(:data, :properties, :name, :label))
    end

    test 'imports correct template when overwriting it from another folder in reverse order' do
      template_importer = subject.new(template_paths: [import_path5, import_path2])
      template = template_importer.templates.find { |t| t[:name] == 'Entity-Creative-Work-1' }

      assert_empty(template_importer.errors)
      assert_not(template.nil?)
      assert(template.dig(:data, :properties)&.key?(:id))
      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:description))
      assert_equal('Titel', template.dig(:data, :properties, :name, :label))
    end

    test 'mixed in properties have lower priority than direct properties' do
      template_importer = subject.new(template_paths: [import_mixin_path1])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Set-1-Creative-Work-1' }

      assert_not(template.nil?)

      assert(template.dig(:data, :properties)&.key?(:name))
      assert(template.dig(:data, :properties)&.key?(:mixed_in_name1))
      assert_not(template.dig(:data, :properties)&.key?(:mixed_in_name2))
      assert(template.dig(:data, :properties)&.key?(:mixed_in_text2))
      assert_equal('Titel', template.dig(:data, :properties, :name, :label))
    end

    test 'mixed in properties take conditions into account' do
      template_importer = subject.new(template_paths: [mixin_with_condition_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Condition-Creative-Work-1' }

      assert_not(template.nil?)

      embedded_template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Condition-Embedded-1' }

      assert_not(embedded_template.nil?)

      assert(template.dig(:data, :properties)&.key?(:mixed_in_name1))
      assert_not(embedded_template.dig(:data, :properties)&.key?(:mixed_in_name1))
    end

    test 'aggregate templates merge all non-existing classification_properties into universal_classifications' do
      template_importer = subject.new(template_paths: [import_path, import_path4, aggregate_path1])
      agg_template_name = MasterData::Templates::AggregateTemplate.aggregate_template_name('Entity-With-Aggregate-Creative-Work-2')
      agg_template = template_importer.templates.find { |t| t[:name] == agg_template_name }

      assert_equal(
        ['aggregate_for.universal_classifications', 'aggregate_for.tags'],
        agg_template.dig(:data, :properties, :universal_classifications, :compute, :parameters)
      )
    end

    test 'extends a child mixin with a base mixin' do
      template_importer = subject.new(template_paths: [mixin_extends_single_base_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Single' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:child_text))
      assert_not(props[:child_text].key?(:extends))
      assert_equal('Child label', props.dig(:child_text, :label))
      assert(props.key?(:base_text))
      assert_not(props[:base_text].key?(:extends))
      assert_equal('Base label', props.dig(:base_text, :label))
    end

    test 'extends a child mixin with multiple base mixins in order' do
      template_importer = subject.new(template_paths: [mixin_extends_multiple_bases_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Multiple' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:child_text))
      assert_not(props[:child_text].key?(:extends))
      assert(props.key?(:base_one_text))
      assert_not(props[:base_one_text].key?(:extends))
      assert(props.key?(:base_two_text))
      assert_not(props[:base_two_text].key?(:extends))
      assert(props.key?(:shared_text))
      assert_not(props[:shared_text].key?(:extends))
      assert(props.key?(:base_three_text))
      assert_not(props[:base_three_text].key?(:extends))
      assert(props.key?(:multi_level_shared_text))
      assert_not(props[:multi_level_shared_text].key?(:extends))

      assert_equal('Base two overrides', props.dig(:shared_text, :label), 'base_two should override base_one because it is listed later in :extends')
      assert_equal('Base three overrides', props.dig(:multi_level_shared_text, :label), 'base_three should override base_two and base_one because it is listed later in :extends')
    end

    test 'resolves transitive mixin inheritance chain' do
      template_importer = subject.new(template_paths: [mixin_extends_transitive_chain_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Transitive' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:base_text), 'child should inherit base_text from base through middle')
      assert_equal('Base label', props.dig(:base_text, :label))

      assert(props.key?(:middle_text), 'child should inherit middle_text from middle')
      assert_equal('Middle label', props.dig(:middle_text, :label))

      assert(props.key?(:child_text), 'child should have its own child_text')
      assert_equal('Child label', props.dig(:child_text, :label))

      assert(props.key?(:shared_text), 'shared_text should be present')
      assert_equal('Child shared', props.dig(:shared_text, :label), 'child should override middle and base for shared_text')
    end

    test 'deep merges nested mixin properties on inheritance' do
      template_importer = subject.new(template_paths: [mixin_extends_nested_merge_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Nested' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:nested_text))
      assert(props.key?(:child_only_text))

      nested = props[:nested_text]

      assert_equal('Child nested label', nested[:label], 'child should override base label')
      assert_equal('string', nested[:type], 'child should inherit type from base')
      assert_equal('translated_value', nested[:storage_location], 'child should inherit storage_location from base')
      assert(nested[:search], 'child should inherit search flag from base')

      assert(nested.key?(:ui), 'ui hash should be present')
      assert(nested[:ui].key?(:show), 'ui:show should be present')
      assert(nested[:ui].key?(:edit), 'ui:edit should be present')
      assert_equal('header', nested.dig(:ui, :show, :content_area), 'ui:show:content_area should be inherited from base')
      assert(nested.dig(:ui, :show, :disabled), 'ui:show:disabled should be added by child')
      assert_equal('text_editor', nested.dig(:ui, :edit, :type), 'ui:edit:type should be inherited from base')
      assert_not(nested.dig(:ui, :edit, :disabled), 'ui:edit:disabled should be added by child')

      assert(nested.key?(:api), 'api hash should be present')
      assert_equal('dc:child', nested.dig(:api, :name), 'api:name should be overridden by child')
      assert_not(nested.dig(:api, :disabled), 'api:disabled should be inherited from base')

      assert(nested.key?(:validations), 'validations hash should be present')
      assert_equal(1, nested.dig(:validations, :min), 'validations:min should be inherited from base')
      assert_equal(10, nested.dig(:validations, :max), 'validations:max should be added by child')
    end

    test 'allows child mixin to override base property type' do
      template_importer = subject.new(template_paths: [mixin_extends_type_override_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Type-Override' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:text_property))

      text_prop = props[:text_property]

      assert_equal('number', text_prop[:type], 'child can override type from base')
      assert_equal('Text property', text_prop[:label], 'label should be inherited from base')
      assert_equal('translated_value', text_prop[:storage_location], 'storage_location should be inherited from base')
      assert_equal('number_input', text_prop.dig(:ui, :edit, :type), 'ui settings should be added by child')
    end

    test 'blocks template loading on circular mixin inheritance' do
      template_importer = subject.new(template_paths: [mixin_extends_cycle_path])

      assert_equal(1, template_importer.mixin_errors.count)
      assert_match(/Mixin 'mixin_[ab]' extends missing base mixin 'mixin_[ab]'/, template_importer.mixin_errors.first)

      assert_nil(template_importer.templates)
    end

    test 'deduplicates repeated base mixins during merge with an idempotent deep-merge' do
      template_importer = subject.new(template_paths: [mixin_extends_duplicate_bases_path])

      assert_empty(template_importer.errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Duplicate' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:child_text))
      assert(props.key?(:base_text))
      assert_equal('Child label', props.dig(:child_text, :label))
      assert_equal('Base label', props.dig(:base_text, :label))
    end

    test 'resolves same-name mixin across paths by scope' do
      template_importer = subject.new(template_paths: [mixin_extends_same_name_config_root, mixin_extends_same_name_vendor_root])

      assert_empty(template_importer.errors)
      assert_empty(template_importer.mixin_errors)

      template = template_importer.templates.find { |t| t[:name] == 'Entity-Mixin-Extends-Same-Name' }

      assert_not(template.nil?)

      props = template.dig(:data, :properties)

      assert(props.key?(:base_text))
      assert_equal('Base label', props.dig(:base_text, :label))
      assert(props.key?(:child_text))
      assert_equal('Child label', props.dig(:child_text, :label))
      assert(props.key?(:shared_text))
      assert_equal('Child shared', props.dig(:shared_text, :label))
    end

    test 'rejects mixin definitions without a name' do
      template_importer = subject.new(template_paths: [mixin_missing_name_path])

      assert_not_empty(template_importer.mixin_errors)
      assert_match(/no_name_mixin\.yml/, template_importer.mixin_errors.first)

      assert_nil(template_importer.templates)
    end

    test 'prefers scope-specific base mixin over generic' do
      template_importer = subject.new(template_paths: [mixin_extends_scope_resolution_path])

      assert_empty(template_importer.errors)
      assert_empty(template_importer.mixin_errors)

      creative_work = template_importer.templates.find { |t| t[:name] == 'Entity-Scope-Creative-Work' }

      assert_not(creative_work.nil?)
      assert_equal('From creative_works base', creative_work.dig(:data, :properties, :base_text, :label), 'CreativeWork template should get creative_works/mixins/base_mixin')
      assert_equal('From child', creative_work.dig(:data, :properties, :child_text, :label))

      place = template_importer.templates.find { |t| t[:name] == 'Place-Scope-Place' }

      assert_not(place.nil?)
      assert_equal('From places base', place.dig(:data, :properties, :base_text, :label), 'Place template should get places/mixins/base_mixin')
      assert_equal('From child', place.dig(:data, :properties, :child_text, :label))
    end

    test 'resolves schema-specific base mixin with same name' do
      base_path = mixin_extends_schema_specific_same_name_base_path
      template_paths = [
        base_path.join('vendor', 'gems', 'datacycle-schema-base', 'config', 'data_definitions'),
        base_path.join('vendor', 'gems', 'datacycle-schema-creative_works', 'config', 'data_definitions'),
        base_path.join('config', 'data_definitions')
      ]
      template_importer = subject.new(template_paths: template_paths)

      assert_empty(template_importer.errors)
      assert_empty(template_importer.mixin_errors)

      creative_work = template_importer.templates.find { |t| t[:name] == 'Entity-Same-Name-Creative-Work' }

      assert_not(creative_work.nil?)
      assert(creative_work.dig(:data, :properties).key?(:base_property), 'Should inherit base_property from base creative_works/child_mixin')
      assert_equal('From base child_mixin (creative_works gem, under creative_works)', creative_work.dig(:data, :properties, :base_property, :label))
      assert(creative_work.dig(:data, :properties).key?(:creative_work_property), 'Should have creative_work_property from creative_works/child_mixin')
      assert_equal('From creative_works child_mixin (extends base)', creative_work.dig(:data, :properties, :creative_work_property, :label))

      place = template_importer.templates.find { |t| t[:name] == 'Place-Same-Name-Place' }

      assert_not(place.nil?)
      assert(place.dig(:data, :properties).key?(:base_property), 'Should inherit base_property from base places/child_mixin')
      assert_equal('From base child_mixin (base gem, under places)', place.dig(:data, :properties, :base_property, :label))
      assert(place.dig(:data, :properties).key?(:place_property), 'Should have place_property from places/child_mixin')
      assert_equal('From places child_mixin (extends base)', place.dig(:data, :properties, :place_property, :label))
    end

    test 'falls back to generic base mixin when scoped base missing' do
      base_path = mixin_extends_generic_same_name_base_path
      template_paths = [
        base_path.join('vendor', 'gems', 'datacycle-schema-base', 'config', 'data_definitions'),
        base_path.join('config', 'data_definitions')
      ]
      template_importer = subject.new(template_paths: template_paths)

      assert_empty(template_importer.errors)
      assert_empty(template_importer.mixin_errors)

      event = template_importer.templates.find { |t| t[:name] == 'Event-Same-Name-Event' }

      assert_not(event.nil?)
      assert(event.dig(:data, :properties).key?(:base_property), 'Should inherit base_property from base events/child_mixin')
      assert_equal('From base child_mixin (base gem)', event.dig(:data, :properties, :base_property, :label))
      assert(event.dig(:data, :properties).key?(:event_property), 'Should have event_property from events/child_mixin')
      assert_equal('From events child_mixin (extends base)', event.dig(:data, :properties, :event_property, :label))
    end

    test 'stops import when mixin base is missing' do
      template_importer = subject.new(template_paths: [mixin_extends_missing_base_path])

      assert_not_empty(template_importer.mixin_errors)
      assert_equal(1, template_importer.mixin_errors.count)
      assert_match(/Mixin 'child_mixin' extends missing base mixin 'non_existent_base_mixin'/, template_importer.mixin_errors.first)

      assert_nil(template_importer.templates)
    end

    test 'reports missing scoped base mixin and aborts template load' do
      base_path = mixin_extends_missing_same_name_base_path
      template_paths = [
        base_path.join('vendor', 'gems', 'datacycle-schema-base', 'config', 'data_definitions'),
        base_path.join('vendor', 'gems', 'datacycle-schema-creative_works', 'config', 'data_definitions'),
        base_path.join('config', 'data_definitions')
      ]
      template_importer = subject.new(template_paths: template_paths)

      assert_empty(template_importer.errors)
      assert_equal(1, template_importer.mixin_errors.count)
      assert_match(
        "Mixin 'child_mixin' extends missing base mixin 'child_mixin' in scope 'events'",
        template_importer.mixin_errors.first
      )

      assert_nil(template_importer.templates)
    end

    test 'reports missing template-specific base mixin and aborts template load' do
      template_importer = subject.new(template_paths: [mixin_extends_template_specific_missing_base_path])

      assert_empty(template_importer.errors)
      assert_equal(1, template_importer.mixin_errors.count)
      assert_match(
        "Mixin 'child_mixin' extends missing base mixin 'non_existent_base_mixin' in template 'Entity-Template-Specific' in scope 'creative_works'",
        template_importer.mixin_errors.first
      )

      assert_nil(template_importer.templates)
    end

    test 'merges mixin properties into template properties' do
      base_path = mixin_extends_property_override_base_path
      template_paths = [
        base_path.join('vendor', 'gems', 'datacycle-schema-base', 'config', 'data_definitions'),
        base_path.join('config', 'data_definitions')
      ]
      template_importer = subject.new(template_paths: template_paths)

      assert_empty(template_importer.errors)
      assert_empty(template_importer.mixin_errors)

      event = template_importer.templates.find { |t| t[:name] == 'Event-Same-Name-Event' }

      assert_not(event.nil?)

      assert(event.dig(:data, :properties).key?(:topic))
      assert_equal('Themenbereich Override', event.dig(:data, :properties, :topic, :label))
      assert_equal('string', event.dig(:data, :properties, :topic, :type))
      assert_equal('translated_value', event.dig(:data, :properties, :topic, :storage_location))
    end

    test 'uses correct mixin properties in final template' do
      base_path = mixin_from_multiple_gems_base_path
      template_paths = [
        base_path.join('vendor', 'gems', 'datacycle-schema-base', 'config', 'data_definitions'),
        base_path.join('vendor', 'gems', 'datacycle-schema-tourism', 'config', 'data_definitions'),
        base_path.join('vendor', 'gems', 'datacycle-schema-creative_content', 'config', 'data_definitions'),
        base_path.join('config', 'data_definitions')
      ]
      template_importer = subject.new(template_paths: template_paths)

      assert_empty(template_importer.errors)
      assert_empty(template_importer.mixin_errors)

      event = template_importer.templates.find { |t| t[:name] == 'Event-Same-Name-Event' }

      assert_not(event.nil?)

      assert(event.dig(:data, :properties).key?(:base_property))
      assert_equal('From main set', event.dig(:data, :properties, :base_property, :label))
      assert_equal('string', event.dig(:data, :properties, :base_property, :type))
      assert_equal('translated_value', event.dig(:data, :properties, :base_property, :storage_location))
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

    def import_path_missing_template
      Rails.root.join('..', 'data_types', 'master_data', 'missing_template_set')
    end

    def non_existent_path
      Rails.root.join('..', 'data_types', '1234567890')
    end

    def import_mixin_path1
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_set_1')
    end

    def aggregate_path1
      Rails.root.join('..', 'data_types', 'master_data', 'aggregate_set_1')
    end

    def mixin_with_condition_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_with_condition_set')
    end

    def expected_templates_for_single_path
      [
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
    end

    def expected_templates_for_multiple_paths
      [
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
    end

    def expected_template_duplicates
      {
        'creative_works.Entity-Creative-Work-1' => [
          import_path2.join('creative_works', 'entity.yml').to_s,
          import_path.join('creative_works', 'entity.yml').to_s
        ]
      }
    end

    def mixin_extends_single_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_single_base')
    end

    def mixin_extends_multiple_bases_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_multiple_bases')
    end

    def mixin_extends_transitive_chain_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_transitive_chain')
    end

    def mixin_extends_nested_merge_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_nested_merge')
    end

    def mixin_extends_type_override_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_type_override')
    end

    def mixin_extends_cycle_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_cycle')
    end

    def mixin_extends_duplicate_bases_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_duplicate_bases')
    end

    def mixin_extends_same_name_config_root
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_same_name', 'config', 'data_definitions')
    end

    def mixin_extends_same_name_vendor_root
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_same_name', 'vendor', 'gems', 'datacycle-schema-child_schema')
    end

    def mixin_missing_name_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_missing_name')
    end

    def mixin_extends_scope_resolution_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_scope_resolution')
    end

    def mixin_extends_schema_specific_same_name_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_schema_specific_same_name_base')
    end

    def mixin_extends_generic_same_name_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_generic_same_name_base')
    end

    def mixin_extends_missing_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_missing_base')
    end

    def mixin_extends_missing_same_name_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_missing_same_name_base')
    end

    def mixin_extends_template_specific_missing_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_template_specific_missing_base')
    end

    def mixin_extends_property_override_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_extends_property_override')
    end

    def mixin_from_multiple_gems_base_path
      Rails.root.join('..', 'data_types', 'master_data', 'mixin_from_multiple_gems')
    end
  end
end
