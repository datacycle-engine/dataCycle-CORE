# frozen_string_literal: true

module DataCycleCore
  module Content
    module ContentFilters
      # Deprecated: no replacement
      def with_classification_alias_names(*_names)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # Deprecated: no replacement
      def with_classification_alias_ids(*_ids)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      # def search
      #   DataCycleCore::Filter::Search.new(nil,nil,true)
      # end

      # Deprecated: no replacement
      def search(_q, _language)
        raise DataCycleCore::Error::DeprecatedMethodError, "Deprecated method not implemented: #{__method__}"
      end

      def with_content_type(type)
        where("schema ->> 'content_type' = ?", type)
      end

      def with_schema_type(type)
        where("schema ->> 'schema_type' = ?", type)
      end

      def without_template_names(*names)
        where.not(template_name: names)
      end

      def with_template_names(*names)
        where(template_name: names)
      end

      def with_default_data_type(classification_alias_names)
        where("schema -> 'properties' -> 'data_type' ->> 'default_value' IN (?)", classification_alias_names)
      end

      def expired_not_release_id(id)
        return unless DataCycleCore::Feature::Releasable.enabled?
        joins(:classifications)
          .where('classification_contents.relation = ?', DataCycleCore::Feature::Releasable.attribute_keys.first)
          .where.not('classification_contents.classification_id = ?', id)
      end

      def expired_not_life_cycle_id(id)
        return if DataCycleCore::Feature::LifeCycle.attribute_keys.blank?
        joins(:classifications)
          .where('classification_contents.relation = ?', DataCycleCore::Feature::LifeCycle.attribute_keys.first)
          .where.not('classification_contents.classification_id = ?', id)
      end
    end
  end
end
