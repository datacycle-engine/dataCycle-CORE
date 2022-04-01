# frozen_string_literal: true

require 'translations/backends/active_record'
require 'translations/backends/table'
require 'translations/active_record/model_translation'

module Translations
  module Backends
    module ActiveRecord
      class Table
        include Translations::Backends::ActiveRecord
        include Translations::Backends::Table

        class << self
          def configure(options)
            table_name = options[:model_class].table_name
            options[:table_name] ||= "#{table_name.singularize}_translations"
            options[:foreign_key] ||= table_name.downcase.singularize.camelize.foreign_key
            if (association_name = options[:association_name]).present?
              options[:subclass_name] ||= association_name.to_s.singularize.camelize.freeze
            else
              options[:association_name] = :translations
              options[:subclass_name] ||= :Translation
            end
            [:foreign_key, :association_name, :subclass_name, :table_name].each { |key| options[key] = options[key].to_sym }
          end

          def build_node(attr, locale)
            aliased_table = model_class.const_get(subclass_name).arel_table.alias(table_alias(locale))
            Arel::Attribute.new(aliased_table, attr, locale, self)
          end

          def apply_scope(relation, predicate, locale = I18n.locale, invert: false)
            visitor = Visitor.new(self, locale)
            join_type = visitor.accept(predicate)
            if join_type
              join_type &&= Visitor::INNER_JOIN if invert
              join_translations(relation, locale, join_type)
            else
              relation
            end
          end

          private

          def join_translations(relation, locale, join_type)
            return relation if already_joined?(relation, locale, join_type)
            m = model_class.arel_table
            t = model_class.const_get(subclass_name).arel_table.alias(table_alias(locale))
            relation.joins(
              m.join(t, join_type)
                .on(t[foreign_key].eq(m[:id])
                  .and(t[:locale].eq(locale)))
              .join_sources
            )
          end

          def already_joined?(relation, locale, join_type)
            join = get_join(relation, locale)
            if join
              return true if (join_type == Visitor::OUTER_JOIN) || join.is_a?(Visitor::INNER_JOIN)
              relation.joins_values = relation.joins_values - [join]
            end
            false
          end

          def get_join(relation, locale)
            relation.joins_values.find { |v| v.is_a?(::Arel::Nodes::Join) && (v.left.name == table_alias(locale).to_s) }
          end
        end

        class Visitor < Arel::Visitor
          private

          def visit_Arel_Nodes_Equality(object) # rubocop:disable Naming/MethodName
            nils, nodes = [object.left, object.right].partition(&:nil?)
            return unless nodes.any?(&method(:visit))
            nils.empty? ? INNER_JOIN : OUTER_JOIN
          end

          def visit_collection(objects)
            objects.map { |obj|
              visit(obj).tap { |visited| return visited if visited == INNER_JOIN }
            }.compact.first
          end
          alias visit_Array visit_collection

          def visit_Arel_Nodes_Or(object) # rubocop:disable Naming/MethodName
            visited = [object.left, object.right].map(&method(:visit))
            if visited.all? { |v| INNER_JOIN == v }
              INNER_JOIN
            elsif visited.any?
              OUTER_JOIN
            end
          end

          def visit_Translations_Arel_Attribute(object) # rubocop:disable Naming/MethodName
            (backend_class.table_name == object.backend_class.options[:table_name]) &&
              (locale == object.locale) && OUTER_JOIN || nil
          end
        end

        setup do |_attributes, options|
          association_name = options[:association_name]
          subclass_name    = options[:subclass_name]

          translation_class =
            if const_defined?(subclass_name, false)
              const_get(subclass_name, false)
            else
              const_set(subclass_name, Class.new(Translations::ActiveRecord::ModelTranslation))
            end

          translation_class.table_name = options[:table_name]

          has_many(
            association_name,
            class_name: translation_class.name,
            foreign_key: options[:foreign_key],
            dependent: :destroy,
            autosave: true,
            inverse_of: :translated_model,
            extend: TranslationsHasManyExtension
          )

          translation_class.belongs_to(
            :translated_model,
            class_name: name,
            foreign_key: options[:foreign_key],
            inverse_of: association_name
          )

          before_save do
            required_attributes = self.class.translation_attributes & translation_class.attribute_names
            send(association_name).destroy_empty_translations(required_attributes)
          end

          module_name = "TranslationArTable#{association_name.to_s.camelcase}"
          unless const_defined?(module_name)
            dupable = Module.new do
              define_method :initialize_dup do |source|
                super(source)
                send("#{association_name}=", source.send(association_name).map(&:dup))
              end
            end
            include const_set(module_name, dupable)
          end
        end

        def translation_for(locale, **_)
          # puts "#{locale.class}"
          # puts "translation_for(#{locale}) --> #{translations.in_locale(locale)}"
          translation = translations.in_locale(locale)
          translation ||= translations.build(locale: locale)
          translation
        end

        module TranslationsHasManyExtension
          def in_locale(locale)
            find { |t| t.locale.to_s == locale.to_s }
          end

          def destroy_empty_translations(required_attributes)
            empty_translations = select { |t| required_attributes.map(&t.method(:send)).none? }
            destroy(empty_translations) if empty_translations.any?
          end
        end
      end
    end
  end
end
