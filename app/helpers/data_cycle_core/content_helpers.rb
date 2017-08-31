module DataCycleCore
  module ContentHelpers
    def content_type
      metadata['validation']['name']
    end

    def read_write?
      metadata['validation']['permissions']['read_write']
    end

    def title
      raise NotImplementedError
    end

    def desc
      raise NotImplementedError
    end

    # def creator
    #   DataCycleCore::User.find(metadata['creator']) if metadata && metadata['creator']
    # end

    def classification_tree_definitions
      metadata['validation']['properties'].select { |key, definition|
        definition['type'] == 'classificationTreeLabel' && definition['editor']
      }.map { |key, definition|
        {key: key}.merge(definition)
      }.sort { |d1, d2|
        d1['editor']['sorting'] <=> d2['editor']['sorting']
      }
    end
  end
end
