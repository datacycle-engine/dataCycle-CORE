# frozen_string_literal: true

module Translations
  module ActiveRecord
    class UniquenessValidator < ::ActiveRecord::Validations::UniquenessValidator
      def validate_each(record, attribute, value)
        klass = record.class

        if (([*options[:scope]] + [attribute]).map(&:to_s) & klass.translation_attributes).present?
          return if value.blank?
          relation = klass.unscoped.__translation_query_scope__ do |m|
            node = m.__send__(attribute)
            options[:case_sensitive] == false ? node.lower.eq(value.downcase) : node.eq(value)
          end
          relation = relation.where.not(klass.primary_key => record.id) if record.persisted?
          relation = translation_scope_relation(record, relation)
          relation = relation.merge(options[:conditions]) if options[:conditions]

          if relation.exists?
            error_options = options.except(:case_sensitive, :scope, :conditions)
            error_options[:value] = value

            record.errors.add(attribute, :taken, error_options)
          end
        else
          super
        end
      end

      private

      def translation_scope_relation(record, relation)
        [*options[:scope]].inject(relation) do |scoped_relation, scope_item|
          scoped_relation.__translation_query_scope__ do |m|
            m.__send__(scope_item).eq(record.send(scope_item))
          end
        end
      end
    end
  end
end
