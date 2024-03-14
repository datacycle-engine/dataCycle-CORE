# frozen_string_literal: true

module VirtualAttributeTestUtilities
  def create_content_dummy(data)
    if data.is_a?(Array)
      data.map { |d| create_content_dummy(d) }.then { |v| DataCycleCore::Thing.by_ordered_values(v.pluck(:id)).tap { |rel| rel.send(:load_records, v) } }
    elsif data.is_a?(Hash)
      Struct.new(*data.keys) {
        def is_a?(class_name)
          class_name == DataCycleCore::Thing
        end

        def class
          DataCycleCore::Thing
        end
      }.new(*data.values.map { |d| create_content_dummy(d) })
    else
      data
    end
  end

  def create_classification_dummy(data)
    if data.is_a?(Array)
      data.map { |d| create_classification_dummy(d) }.then { |v| DataCycleCore::Classification.by_ordered_values(v.pluck(:id)).tap { |rel| rel.send(:load_records, v) } }
    elsif data.is_a?(Hash)
      Struct.new(*data.keys) {
        def is_a?(class_name)
          class_name == DataCycleCore::Classification
        end

        def class
          DataCycleCore::Classification
        end
      }.new(*data.values.map { |d| create_classification_dummy(d) })
    else
      data
    end
  end
end
