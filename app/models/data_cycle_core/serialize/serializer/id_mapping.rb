# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class IdMapping < Base
        class << self
          def translatable?
            false
          end

          def mime_type
            'text/csv'
          end

          def serialize_thing(content:, language:, user:, **_options)
            content = content.first if content.is_a?(Array)

            serialize_contents(
              content:,
              contents: DataCycleCore::Thing.where(id: content.id),
              language:,
              user:
            )
          end

          def serialize_watch_list(content:, language:, user:, **_options)
            watch_list = content.is_a?(Array) ? content.first : content

            serialize_contents(
              content: watch_list,
              contents: watch_list.things,
              language:,
              user:
            )
          end

          def serialize_stored_filter(content:, language:, user:, **_options)
            stored_filter = content.is_a?(Array) ? content.first : content

            serialize_contents(
              content: stored_filter,
              contents: stored_filter.apply.query,
              language:,
              user:
            )
          end

          private

          def config_hash
            config = DataCycleCore::Feature::Serialize.enabled_serializers[name.demodulize.underscore]
            return {} unless config.is_a?(Hash)

            config
          end

          def concept_scheme_sql
            concept_scheme_config = config_hash['concept_scheme_ids']
            if concept_scheme_config.is_a?(Hash)
              concept_scheme_ids = Array.wrap(concept_scheme_config['ids'])
              attribute = concept_scheme_config['attribute'] || 'external_key'
            else
              concept_scheme_ids = Array.wrap(concept_scheme_config)
              attribute = 'external_key'
            end

            return [] if concept_scheme_ids.blank?

            select_sql = <<~SQL.squish
              , JSONB_AGG(
                  DISTINCT jsonb_build_object(
                    'concept_scheme',
                    cs.name,
                    'external_key',
                    c.#{attribute}
                  )
                ) FILTER (
                  WHERE c.external_key IS NOT NULL
                ) AS concept_schemes
            SQL

            sql = <<~SQL.squish
              LEFT OUTER JOIN collected_classification_contents ccc ON ccc.thing_id = contents.id
              AND ccc.link_type IN ('direct', 'related')
              AND ccc.classification_tree_label_id IN (?)
              LEFT OUTER JOIN concept_schemes cs ON cs.id = ccc.classification_tree_label_id
              LEFT OUTER JOIN concepts c ON c.id = ccc.classification_alias_id
              AND c.external_system_id IS NOT NULL
              AND c.external_key IS NOT NULL
            SQL

            [
              select_sql,
              ActiveRecord::Base.send(:sanitize_sql_array, [sql, concept_scheme_ids])
            ]
          end

          def dc_link_sql
            return '' unless config_hash['dc_link']

            root_url = File.join(DataCycleCore::UrlService.instance.root_url, 'things/')
            sql = <<~SQL.squish
              , CONCAT(?, contents.id) AS "dc_link"
            SQL

            ActiveRecord::Base.send(:sanitize_sql_array, [sql, root_url])
          end

          def name_sql
            return [] unless config_hash['name']

            locale = config_hash['name'] if config_hash['name'].is_a?(String) &&
                                            I18n.available_locales.map(&:to_s).include?(config_hash['name'])
            locale = I18n.default_locale.to_s if locale.blank?

            select_sql = <<~SQL.squish
              , MAX(thing_translations.content ->> 'name') AS "name"
            SQL

            sql = <<~SQL.squish
              LEFT OUTER JOIN thing_translations ON thing_translations.thing_id = contents.id
              AND thing_translations.locale IN (?)
            SQL

            [
              select_sql,
              ActiveRecord::Base.send(:sanitize_sql_array, [sql, locale])
            ]
          end

          def external_system_syncs_sql
            return [] if config_hash['external_system_syncs'] == false

            select_sql = <<~SQL.squish
              , JSONB_AGG(
                DISTINCT jsonb_build_object(
                  'external_system',
                  es2.name,
                  'external_key',
                  ess.external_key
                )
              ) FILTER (
                WHERE ess.external_key IS NOT NULL
              ) AS external_relations
            SQL

            sql = <<~SQL.squish
              LEFT OUTER JOIN external_system_syncs ess ON ess.syncable_id = contents.id
              AND ess.external_key != contents.id::VARCHAR
              LEFT OUTER JOIN external_systems es2 ON es2.id = ess.external_system_id
            SQL

            [
              select_sql,
              sql
            ]
          end

          def result(contents)
            ess_sql = external_system_syncs_sql
            cs_sql = concept_scheme_sql
            dcl_sql = dc_link_sql
            n_sql = name_sql

            sql = <<~SQL.squish
              WITH contents AS (
                #{contents.select(:id, :external_source_id, :external_key).reorder(nil).to_sql}
              )
              SELECT contents.id,
                MAX(es1.name) AS "external_system",
                MAX(contents.external_key) AS "external_key"
                #{ess_sql[0]}
                #{cs_sql[0]}
                #{dcl_sql}
                #{n_sql[0]}
              FROM contents
                LEFT OUTER JOIN external_systems es1 ON es1.id = contents.external_source_id
                #{ess_sql[1]}
                #{cs_sql[1]}
                #{n_sql[1]}
              GROUP BY contents.id
            SQL

            sanitized_sql = ActiveRecord::Base.send(:sanitize_sql, sql)
            ActiveRecord::Base.connection.select_all(sanitized_sql).to_cast_array
          end

          def data_headers(data, title_proc)
            data.map { |v|
              title_proc.call(v)
                .compact
                .sort
                .group_by(&:to_s)
                .to_h { |k, a| [k, a.count] }
            }.reduce({}) { |b, v| b.merge(v) { |_, v1, v2| [v1, v2].max } }
              .sort.to_h
          end

          def data_to_csv(data, headers, es_headers, cs_headers)
            CSV.generate do |csv|
              csv << headers

              data.each do |row|
                v = [row['id']]
                v << row['dc_link'] if headers.include?('URL')
                v << row['name'] if headers.include?('Name')
                relations = Array.wrap(row['external_relations'])
                relations.unshift({ 'external_system' => row['external_system'], 'external_key' => row['external_key'] }) if row['external_system'].present? || row['external_key'].present?

                es_headers.each do |key, count|
                  values = relations.select { |r| r['external_system'] == key }.map { |r| r['external_key'] }
                  v.concat(values)
                  v.concat(Array.new(count - values.size))
                end

                cs_relations = Array.wrap(row['concept_schemes'])
                cs_headers.each do |key, count|
                  values = cs_relations.select { |r| r['concept_scheme'] == key }.map { |r| r['external_key'] }
                  v.concat(values)
                  v.concat(Array.new(count - values.size))
                end

                csv << v
              end
            end
          end

          def serialize_contents(contents:, content:, language:, **)
            raw_data = result(contents)
            headers = ['Id']
            headers << 'URL' if config_hash['dc_link']
            headers << 'Name' if config_hash['name']
            es_headers = data_headers(raw_data, ->(v) { Array.wrap(v['external_system']) + Array.wrap(v['external_relations']&.pluck('external_system')) })
            es_headers.each do |key, count|
              headers.concat(Array.new(count, key))
            end

            cs_headers = data_headers(raw_data, ->(v) { Array.wrap(v['concept_schemes']&.pluck('concept_scheme')) })
            cs_headers.each do |key, count|
              headers.concat(Array.new(count, key))
            end

            data = data_to_csv(raw_data, headers, es_headers, cs_headers)

            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [DataCycleCore::Serialize::SerializedData::Content.new(
                data:,
                mime_type:,
                file_name: file_name(content:, language:),
                id: content.id
              )]
            )
          end
        end
      end
    end
  end
end
