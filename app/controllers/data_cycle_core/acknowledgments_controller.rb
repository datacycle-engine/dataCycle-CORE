# frozen_string_literal: true

module DataCycleCore
  class AcknowledgmentsController < ApplicationController
    def index
      @package_groups = [
        {
          name: 'Server (Ruby)',
          packages: ruby_gems
        },
        {
          name: 'Client (JavaScript)',
          packages: npm_packages
        }
      ]
    end

    def license
      render_package_file('license_files')
    end

    def notice
      render_package_file('notice_files')
    end

    def render_package_file(allowed_files_attribute)
      package = (ruby_gems + npm_packages).find do |p|
        p['name'] == package_params['package'] && p['version'] = package_params['version']
      end

      file = File.join(package['base_path'], package[allowed_files_attribute].find { |f| f == package_params['file'] })

      if File.file?(file)
        render file:, layout: false
      else
        render not_found
      end
    end

    def package_params
      params.permit(:package, :version, :file)
    end

    private

    def acknowledgments
      @acknowledgments ||= Acknowledgments.new
    end

    def ruby_gems
      acknowledgments.ruby_gems
    end

    def npm_packages
      acknowledgments.npm_packages
    end
  end
end
