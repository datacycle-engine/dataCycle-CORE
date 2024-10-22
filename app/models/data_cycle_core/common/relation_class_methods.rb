# frozen_string_literal: true

raise 'ActiveRecord::Relation#load_records is no longer available, check patch!' unless ActiveRecord::Relation.method_defined? :load_records
raise 'ActiveRecord::Relation#load_records arity != 1, check patch!' unless ActiveRecord::Relation.instance_method(:load_records).arity == 1

module DataCycleCore
  module Common
    module RelationClassMethods
      def load_relation(relation_name:, scope: nil, preload: false)
        query = current_scope || all

        relation_name = relation_name.to_sym
        custom_scope = !scope.nil?

        if scope.nil?
          reflection = reflect_on_association(relation_name)
          scope = reflection.klass.default_scoped.where(reflection.foreign_key.to_sym => query.pluck(reflection.association_primary_key.to_sym))
          scope = reflection.scope_for(scope) if reflection.scope
        end

        if query.loaded? && query.none?
          scope.none
        elsif !custom_scope && (query.loaded? || preload.present?)
          preload = [] unless preload.is_a?(::Array) || preload.is_a?(::Hash)
          DataCycleCore::PreloadService.preload(query.to_a, [relation_name => preload], custom_scope ? scope : nil)
          scope.tap { |rel| rel.send(:load_records, query.flat_map(&relation_name).uniq) }
        elsif custom_scope
          preload = [] unless preload.is_a?(::Array) || preload.is_a?(::Hash)
          scope.preload(preload)
        else # rubocop:disable Lint/DuplicateBranch
          scope
        end
      end
    end
  end
end
