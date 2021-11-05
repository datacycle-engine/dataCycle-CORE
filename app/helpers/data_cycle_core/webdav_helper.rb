# frozen_string_literal: true

module DataCycleCore
  module WebdavHelper
    ALLOWED_PROPS = [
      'creationdate', 'displayname', 'getcontentlength', 'getcontenttype',
      'getetag', 'getlastmodified', 'resourcetype'
    ].freeze

    def render_partial(template)
      version = @version || 1
      "data_cycle_core/webdav/v#{version}/resources/#{template}"
    end

    def content_partial(partial, parameters)
      content_parameter = parameters[:content].class.class_name.underscore
      partials = [
        "#{content_parameter}_#{parameters[:content].template_name.underscore}_#{partial}",
        "#{content_parameter}_#{partial}",
        "content_#{partial}",
        partial
      ]
      version = @version || 1
      partials_prefix = "data_cycle_core/webdav/v#{version}/resources/"

      return first_existing_partial(partials, partials_prefix), parameters.merge(cache: true)
    end

    def first_existing_xml_partial(partials, prefix)
      partials.each do |partial|
        next unless lookup_context.exists?(partial, [prefix], true)
        return prefix + partial
      end
      # puts "could not find partial for parameters -> partials: #{partials}, prefix: #{prefix}"
    end

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
        .select { |k, _| k =~ /^HTTP_/ }
        .map { |k, v| { k[5..-1] => v } }
        .inject(&:merge)
    end

    def propstat(thing)
    end
  end
end
