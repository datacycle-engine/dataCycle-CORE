# frozen-string-literal: true

module Translations
  module Plugins
    # Adds a scope which enables querying on translated attributes using +where+ and
    # +not+ as if they were normal attributes. Under the hood, this plugin uses the
    # generic +build_node+ and +apply_scope+ methods implemented in each backend
    # class to build ActiveRecord queries from Arel nodes. The plugin also adds
    # +find_by_<attribute>+ shortcuts for translated attributes.
    # The query scope applies to all translated attributes once the plugin has been
    # enabled for any one attribute on the model.
    module ActiveRecord
      module Query
        class << self
          def apply(names, model_class, backend_class)
            # puts "*** Translations::Plugins::ActiveRecord::Query.apply(#{names}, #{model_class}, #{backend_class})"
            model_class.class_eval do
              extend QueryMethod
              extend FindByMethods.new(*names)
              singleton_class.send :alias_method, Translations.query_method, :__translation_query_scope__
            end
            backend_class.include self
          end

          def attribute_alias(attribute, locale = I18n.locale)
            format('__translation_%<attribute>s_%<locale>s__', { attribute: attribute, locale: Translations.normalize_locale(locale) })
          end
        end

        def read(locale, **)
          if model_attributes_defined? && model_attributes.key?(alias_ = Query.attribute_alias(attribute, locale))
            model_attributes[alias_].value
          else
            super
          end
        end

        private

        def model_attributes_defined?
          model.instance_variable_defined?(:@attributes)
        end

        def model_attributes
          model.instance_variable_get(:@attributes)
        end

        module QueryMethod
          def __translation_query_scope__(locale: I18n.locale, &block)
            if block_given?
              VirtualRow.build_query(self, locale, &block)
            else
              all.extending(QueryExtension)
            end
          end
        end

        class VirtualRow < BasicObject
          attr_reader :__backends

          def initialize(model_class, locale)
            @model_class = model_class
            @locale = locale
            @__backends = []
          end

          def method_missing(m, *) # rubocop:disable Style/MissingRespondToMissing
            if @model_class.translation_attribute?(m)
              @__backends |= [@model_class.translation_backend_class(m)]
              @model_class.translation_backend_class(m).build_node(m, @locale)
            elsif @model_class.column_names.include?(m.to_s)
              @model_class.arel_table[m]
            else
              super
            end
          end

          class << self
            def build_query(klass, locale, &block)
              row = new(klass, locale)
              query = block.arity.zero? ? row.instance_eval(&block) : yield(row)

              if query.is_a?(::ActiveRecord::Relation)
                predicates = query.arel.constraints
                apply_scopes(klass.all, row.__backends, locale, predicates).merge(query)
              else
                apply_scopes(klass.all, row.__backends, locale, query).where(query)
              end
            end

            private

            def apply_scopes(scope, backends, locale, predicates)
              backends.inject(scope) { |r, b| b.apply_scope(r, predicates, locale) }
            end
          end
        end
        private_constant :QueryMethod, :VirtualRow

        module QueryExtension
          def where!(opts, *rest)
            QueryBuilder.build(self, opts) do |untranslated_opts|
              untranslated_opts ? super(untranslated_opts, *rest) : super
            end
          end

          def where(opts = :chain, *rest)
            if opts == :chain
              WhereChain.new(spawn)
            else
              super
            end
          end

          def order(opts, *rest)
            case opts
            when Symbol, String
              @klass.translation_attribute?(opts) ? order({ opts => :asc }, *rest) : super
            when ::Hash
              i18n_keys, keys = opts.keys.partition(&@klass.method(:translation_attribute?))
              return super if i18n_keys.empty?

              base = keys.empty? ? self : super(opts.slice(keys))

              i18n_keys.inject(base) do |query, key|
                backend_class = @klass.translation_backend_class(key)
                dir = opts[key]
                node = backend_node(key)
                backend_class.apply_scope(query, node).order(node.send(dir.downcase))
              end
            else
              super
            end
          end

          ['pluck', 'group', 'select'].each do |method_name|
            define_method method_name do |*attrs, &block|
              return super(*attrs, &block) if method_name == 'select' && block.present?

              if ::ActiveRecord::VERSION::STRING < '7.0'
                return super(*attrs, &block) unless @klass.respond_to?(:translation_attribute?)
              end

              return super(*attrs) unless attrs.any?(&@klass.method(:translation_attribute?))

              keys = attrs.dup

              base = keys.each_with_index.inject(self) do |query, (key, index)|
                next query unless @klass.translation_attribute?(key)
                keys[index] = backend_node(key)
                if method_name == 'select'
                  keys[index] = keys[index]
                    .as(::Translations::Plugins::ActiveRecord::Query.attribute_alias(key.to_s))
                end
                @klass.translation_backend_class(key).apply_scope(query, backend_node(key))
              end

              base.public_send(method_name, *keys)
            end
          end

          def backend_node(name, locale = I18n.locale)
            @klass.translation_backend_class(name)[name, locale]
          end

          class WhereChain < ::ActiveRecord::QueryMethods::WhereChain
            def not(opts, *rest)
              QueryBuilder.build(@scope, opts, invert: true) do |untranslated_opts|
                untranslated_opts ? super(untranslated_opts, *rest) : super
              end
            end
          end

          module QueryBuilder
            IDENTITY = ->(x) { x }.freeze

            class << self
              def build(scope, where_opts, invert: false, &block)
                return yield unless where_opts.is_a?(::Hash)

                opts = where_opts.with_indifferent_access
                locale = opts.delete(:locale) || I18n.locale

                _build(scope, opts, locale, invert, &block)
              end

              private

              def _build(scope, opts, locale, invert)
                return yield unless scope.respond_to?(:translation_modules)

                keys = opts.keys.map(&:to_s)
                predicates = []

                query_map = scope.translation_modules.inject(IDENTITY) do |qm, mod|
                  hash_keys = nil
                  i18n_keys = nil
                  hash_keys = opts.dig(scope.table_name).keys.map(&:to_s) if keys.include?(scope.table_name.to_s)

                  if hash_keys.blank?
                    i18n_keys = mod.names & keys
                  else
                    i18n_keys = mod.names & hash_keys
                  end
                  next qm if i18n_keys.empty?

                  mod_predicates = i18n_keys.map do |key|
                    value = hash_keys.blank? ? opts.delete(key) : opts[scope.table_name].delete(key)
                    opts.delete(scope.table_name) if opts[scope.table_name] == {}
                    build_predicate(scope.backend_node(key.to_sym, locale), value)
                  end
                  invert_predicates!(mod_predicates) if invert
                  predicates += mod_predicates

                  ->(r) { mod.backend_class.apply_scope(qm[r], mod_predicates, locale, invert: invert) }
                end

                return yield if query_map == IDENTITY

                relation = opts.empty? ? scope : yield(opts)
                query_map[relation.where(predicates.inject(&:and))]
              end

              def build_predicate(node, values)
                nils, vals = partition_values(values)

                return node.eq(nil) if vals.empty?

                predicate = vals.length == 1 ? node.eq(vals.first) : node.in(vals)
                predicate = predicate.or(node.eq(nil)) unless nils.empty?
                predicate
              end

              def partition_values(values)
                Array.wrap(values).uniq.partition(&:nil?)
              end

              def invert_predicates!(predicates)
                predicates.map!(&method(:invert_predicate))
              end

              # Adapted from AR::Relation::WhereClause#invert_predicate
              def invert_predicate(predicate)
                case predicate
                when ::Arel::Nodes::In
                  ::Arel::Nodes::NotIn.new(predicate.left, predicate.right)
                when ::Arel::Nodes::Equality
                  ::Arel::Nodes::NotEqual.new(predicate.left, predicate.right)
                else
                  ::Arel::Nodes::Not.new(predicate)
                end
              end
            end
          end

          private_constant :WhereChain, :QueryBuilder
        end

        class FindByMethods < Module
          def initialize(*attributes)
            attributes.each do |attribute|
              module_eval <<-EOM, __FILE__, __LINE__ + 1
              def find_by_#{attribute}(value)
                find_by(#{attribute}: value)
              end
              EOM
            end
          end
        end

        private_constant :QueryExtension, :FindByMethods
      end
    end
  end
end
