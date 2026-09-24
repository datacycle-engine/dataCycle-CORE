# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Asset
        extend DataCycleCore::Engine.routes.url_helpers

        CONTENT_TYPE_MAPPING = {
          'Bild' => 'image',
          'ImageObject' => 'image',
          'Audio' => 'audio',
          'AudioObject' => 'audio',
          'Video' => 'video',
          'VideoObject' => 'video'
        }.freeze

        # The extension of a server-side program (https://example.com/bild.php?id=5) tells which
        # script renders the file, not its format: php alone would store image/x-httpd-php for a Bild.
        SCRIPT_EXTENSIONS = ['php', 'pl', 'cgi', 'asp', 'aspx', 'jsp'].freeze

        class << self
          def url_options
            Rails.application.config.action_mailer.default_url_options
          end

          def file_name(computed_parameters:, **_args)
            DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:name)&.to_s
          end

          def file_size(computed_parameters:, **_args)
            DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:file_size)&.to_i
          end

          def file_format(computed_parameters:, data_hash:, content:, **_args)
            content_type = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)&.try(:content_type)
            return content_type if content_type.present?

            mapped_content_type = CONTENT_TYPE_MAPPING[content.template_name]

            mime_type_from_url(data_hash['content_url'])
              &.then { |s| mapped_content_type.present? ? s.gsub('application', mapped_content_type.to_s) : s }
          end

          def file_type_classification(computed_parameters:, computed_definition:, **_args)
            file_format_path = computed_parameters.values.first&.split('/')

            return [] if file_format_path.blank?

            concept_candidate = DataCycleCore::Concept
              .for_tree(computed_definition&.dig('tree_label'))
              .includes(:concept_path)
              .where(concept_paths: { full_path_names: file_format_path.reverse.append(computed_definition&.dig('tree_label')) })
              .limit(1)
              .pluck(:id)

            return Array.wrap(concept_candidate) if concept_candidate.present?

            tree_label = DataCycleCore::ConceptScheme.find_by(name: computed_definition&.dig('tree_label'))

            Array.wrap(tree_label&.create_concept(*Array.wrap(file_format_path))&.id)
          end

          def content_url(content:, computed_parameters:, **_args)
            asset = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)

            return if asset.nil?

            local_blob_url(id: content.id, file: asset.filename)
          end

          def content_url_from_slug(content:, computed_parameters:, **_args)
            asset = DataCycleCore::Asset.find_by(id: computed_parameters['asset'])

            return if asset.nil?

            slug = if I18n.locale == content.first_available_locale(:de)
                     computed_parameters['slug']
                   else
                     I18n.with_locale(content.first_available_locale(:de)) do
                       content.try(:slug) || computed_parameters['slug']
                     end
                   end

            local_blob_url(id: "#{slug}.#{asset.file_extension}")
          end

          def asset_url_with_transformation(computed_parameters:, computed_definition:, **_args)
            asset = DataCycleCore::Asset.find_by(id: computed_parameters.values.first)

            DataCycleCore::ActiveStorageService.with_current_options do
              asset.try(:dynamic, computed_definition.dig('compute', 'transformation'))&.url
            end
          end

          def imgproxy_url(content:, key:, computed_parameters:, computed_definition:, **_args)
            # check if any attributes changed
            changed = computed_parameters.any? { |k, v| v != content&.attribute_to_h(k) }
            return content.try(key) unless changed

            variant = computed_definition&.dig('compute', 'transformation', 'version')
            image_processing = computed_definition&.dig('compute', 'processing') || {}
            DataCycleCore::Feature::GravityEditor.transform_gravity!(image_processing, computed_parameters) if image_processing.present? && DataCycleCore::Feature::GravityEditor.allowed?(content)
            DataCycleCore::Feature::FocusPointEditor.apply_focus_point!(image_processing, computed_parameters) if image_processing.present? && DataCycleCore::Feature::FocusPointEditor.allowed?(content)

            DataCycleCore::Feature::ImageProxy.process_image(
              content: thing_dummy(content:, computed_parameters:),
              variant:,
              image_processing:
            )
          end

          # :compute:
          #   :module: Asset
          #   :method: etag
          #   :parameters:
          #     - asset
          #     - content_url
          def etag(content:, computed_parameters:, **_args)
            response = Faraday.default_connection.head(computed_parameters['content_url']) do |f|
              f.headers['If-None-Match'] = content.try(:etag)
            end

            return response['etag'] if response.status == 200

            nil
          rescue StandardError
            nil
          end

          private

          # Reads the extension off the last path segment, else off the end of the query string,
          # where a script serving the file names it (.../download.php?file=prospekt.pdf). Reading
          # both as one string would join the query to the extension (.../dsc-4611.jpg?r=1 would
          # give "jpg?r=1"). Inner segments are skipped because one can be a host, and "org" in
          # .../unsafe/300x200/www.example.org/image would read as application/vnd.lotus-organizer.
          # File.extname would miss the bare ".jpg" that the oastatic URLs end in (.../54123107/.jpg).
          #
          # @return [String, nil] a MIME type, or nil for a URL carrying no extension we know
          def mime_type_from_url(url)
            uri = Addressable::URI.parse(url)
            return if uri.nil?

            [uri.path.split('/').last, uri.query].filter_map { |tail|
              extension = tail.to_s[/\.([a-z0-9]+)\z/i, 1].to_s.downcase
              MiniMime.lookup_by_extension(extension)&.content_type unless SCRIPT_EXTENSIONS.include?(extension)
            }.first
          rescue Addressable::URI::InvalidURIError
            nil
          end

          def thing_dummy(content:, computed_parameters:)
            return if content.nil?

            thing_dummy = content.thing_template.template_thing
            thing_dummy.id = content.id
            thing_dummy.cache_valid_since = content.cache_valid_since

            computed_parameters&.each do |key, value|
              thing_dummy.set_memoized_attribute(key, value)
            end

            thing_dummy
          end
        end
      end
    end
  end
end
