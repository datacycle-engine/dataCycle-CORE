# frozen_string_literal: true

module VirtualAttributeTestUtilities
  def create_content_dummy(data)
    create_dummy(data, DataCycleCore::Thing)
  end

  def create_classification_dummy(data)
    create_dummy(data, DataCycleCore::Classification)
  end

  def create_classification_alias_dummy(data)
    create_dummy(data, DataCycleCore::ClassificationAlias)
  end

  def create_schedule_dummy(data)
    create_dummy(data, DataCycleCore::Schedule)
  end

  def create_dummy(data, klass)
    if data.is_a?(Array)
      data.map { |d| create_dummy(d, klass) }.then { |v| klass.by_ordered_values(v.pluck(:id)).tap { |rel| rel.send(:load_records, v) } }
    elsif data.is_a?(::Hash)
      Struct.new(*data.keys.except(:id), :id, :klass, keyword_init: true) {
        def initialize(id: SecureRandom.uuid, **args)
          super
        end

        def is_a?(class_name)
          class_name == klass
        end

        def class
          klass
        end

        if klass == DataCycleCore::ClassificationAlias
          def name
            name_i18n.dig(I18n.locale.to_s)
          end
        end
      }.new(klass:, **data.transform_values { |d| create_dummy(d, klass) })
    else
      data
    end
  end
end
