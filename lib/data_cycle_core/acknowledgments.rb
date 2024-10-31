# frozen_string_literal: true

module DataCycleCore
  class Acknowledgments
    PACKAGE_INFO_PATH = 'public/package_infos.json'

    NODE_MODULES_PATH = 'node_modules'

    def self.extract_ruby_gem_infos
      Gem::Specification.map do |gem|
        {
          'type' => 'gem',
          'name' => gem.name,
          'version' => gem.version.to_s,
          'license' => gem.license,
          'description' => gem.summary,
          'homepage' => gem.homepage,
          'base_path' => gem.full_gem_path,
          'license_files' => Dir[File.join(gem.full_gem_path, '*')]
            .select { |f| File.file?(f) }
            .map { |p| p.split('/').last }
            .select { |f| f.include?('LICENSE') },
          'notice_files' => Dir[File.join(gem.full_gem_path, '*')]
            .select { |f| File.file?(f) }
            .map { |p| p.split('/').last }
            .select { |f| f.include?('NOTICE') }
        }.compact
      end
    end

    def self.extract_npm_package_infos
      default_options = '--json --non-interactive --no-progress --prefer-offline --silent'

      JSON.parse(`yarn list #{default_options}`).dig('data', 'trees').map { |package|
        begin
          {
            'type' => 'npm',
            'full-name' => package['name'],
            'version' => package['name'].sub(/^.*@([^@]*)$/, '\1')
          }.merge(
            (JSON.parse(`yarn info #{package['name']} #{default_options}`)['data'] || {}).select { |k, _|
              ['name', 'description', 'license', 'homepage'].include?(k)
            }.then do |package_info|
              package_info.merge({
                'base_path' => File.join(NODE_MODULES_PATH, package_info['name']),
                'license_files' => Dir[File.join(NODE_MODULES_PATH, package_info['name'], '*')]
                  .select { |f| File.file?(f) }
                  .map { |p| p.split('/').last }
                  .select { |f| f.include?('LICENSE') },
                'notice_files' => Dir[File.join(NODE_MODULES_PATH, package_info['name'], '*')]
                  .select { |f| File.file?(f) }
                  .map { |p| p.split('/').last }
                  .select { |f| f.include?('NOTICE') }
              })
            end
          )
        rescue JSON::ParserError
          {}
        end
      }.compact_blank
    end

    def packages
      @packages ||= JSON.parse(File.read(PACKAGE_INFO_PATH))
    end

    def ruby_gems
      packages.select { |p| p['type'] == 'gem' }
    end

    def npm_packages
      packages.select { |p| p['type'] == 'npm' }
    end
  end
end
