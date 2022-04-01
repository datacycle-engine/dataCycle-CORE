# frozen_string_literal: true

module DataCycleCore
  module WebdavHelper
    ALLOWED_PROPS = [
      'creationdate', 'displayname', 'getcontentlength', 'getcontenttype',
      'getetag', 'getlastmodified', 'resourcetype'
    ].freeze

    EXCLUDE_THING_PROPERTIES = ['id', 'slug'].freeze

    def parse_request(body)
      data = Nokogiri::XML(body)
      data.remove_namespaces!
      props = data.xpath('//propfind/allprop')
      return ALLOWED_PROPS if props.present? || body.blank?
      props = data.xpath('//propfind/prop')&.first
      return [] if props.blank?
      props&.children&.map { |i| ALLOWED_PROPS.include?(i.name.downcase) ? i.name.downcase : nil }&.compact || []
    end

    def parse_header(request)
      request
        .env
        .select { |k, _| k.start_with?('HTTP_') }
        .map { |k, v| { k[5..-1] => v } }
        .inject(&:merge)
    end

    def propstat(thing)
      return create_resource(thing) if thing.assets.blank?
      asset = thing.assets.first
      {
        file_name: thing.slug + get_ext(asset.file&.file_name),
        display_name: asset.file&.file_name,
        last_modified: thing.updated_at.httpdate,
        content_length: asset.file&.size,
        etag: %("#{File.mtime(asset.file.file.file)}-#{asset.file.try(:size)}"),
        content_type: asset&.content_type
      }
    end

    def get_ext(file_name)
      return nil if file_name.blank?
      ext = file_name.split('.')&.last
      return nil if ext.blank?
      ".#{ext}"
    end

    def create_resource(thing)
      file = generate_file(thing)
      {
        file_name: [thing.slug, '.txt'].join,
        display_name: [thing.name, '.txt'].join,
        last_modified: thing.updated_at.httpdate,
        content_length: file.size,
        etag: %("#{thing.updated_at.httpdate}-#{file.size}"),
        content_type: 'text/plain'
      }
    end

    def generate_file(thing)
      (["#{thing.template_name} (#{thing.id})\n"] +
        thing
          .plain_property_names
          .map { |i| thing.send(i).present? && !i.in?(EXCLUDE_THING_PROPERTIES) ? ["#{thing.properties_for(i).dig('label')}:", "#{thing.send(i)}\n"] : nil }
          .flatten
          .compact +
        ['Klassifizierungen:'] +
        thing
          .classification_aliases
          .map { |i| i.classification_alias_path.full_path_names.reverse.join(' > ') }
      ).join("\n")
    end
  end
end
