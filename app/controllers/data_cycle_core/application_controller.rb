module DataCycleCore
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    protected
      def add_breadcrumb type, name, url = ''
        @breadcrumbs ||= []
        url = eval(url) if url =~ /_path|_url|@/
        @breadcrumbs << [type, name, url]
      end
    
      def self.add_breadcrumb type, name, url, options = {}
        before_filter options do |controller|
          controller.send(:add_breadcrumb, type, name, url)
        end
      end

  end
end
