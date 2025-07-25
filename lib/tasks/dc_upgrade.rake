# frozen_string_literal: true

namespace :dc do
  namespace :upgrade do
    desc 'copy core templates to project'
    task :copy_templates, [:folder] => :environment do |_, args|
      abort('Please provide a folder name') if args.folder.nil?

      project_path = Rails.root
      template_path = DataCycleCore::Engine.root.join('lib/templates', args.folder)

      Dir.glob(template_path.join('**', '*'), File::FNM_DOTMATCH).each do |f|
        next unless File.file?(f)

        file_name = File.basename(f, '.template')
        file_path = File.dirname(f)
        dest_path = project_path.join(file_path.gsub(template_path.to_s, ''))

        FileUtils.mkdir_p(dest_path)
        FileUtils.cp(f, dest_path.join(file_name))
      end
    end

    desc 'override some files in project from core templates'
    task rails71: :environment do
      project_path = Rails.root
      template_path = DataCycleCore::Engine.root.join('lib/templates/rails_7_1/')

      puts 'copying templates ...'
      Dir.glob(template_path.join('**', '*')).each do |f|
        next unless File.file?(f)

        file_name = File.basename(f, '.template')
        file_path = File.dirname(f)
        dest_path = project_path.join(file_path.gsub(template_path.to_s, ''))

        FileUtils.mkdir_p(dest_path)
        FileUtils.cp(f, dest_path.join(file_name))
      end

      puts 'fix Dotenv::Railtie.load ...'
      # replace Dotenv::Railtie.load with Dotenv::Rails.load in test/test_helper.rb
      test_helper = Rails.root.join('test', 'test_helper.rb')
      if File.exist?(test_helper)
        text = File.read(test_helper)
        new_text = text.gsub('Dotenv::Railtie.load', 'Dotenv::Rails.load')
        File.write(test_helper, new_text)
      end

      puts 'remove config/secrets.yml ...'
      secrets = Rails.root.join('config', 'secrets.yml')
      FileUtils.rm_f(secrets)

      puts 'migrate files ...'
      manual_action_required = []
      # migrate files
      Rails.root.glob('**/*.{rb,erb,rake,yml}').each do |f|
        next if f.to_s.include?('vendor')

        if File.foreach(f).grep(Regexp.new('.ids')).present?
          text = File.read(f)
          new_text = text.gsub('.ids', '.pluck(:id)')
          File.write(f, new_text)
        end

        if File.foreach(f).grep(Regexp.new('ActiveRecord::Associations::Preloader.new.preload')).present?
          text = File.read(f)
          new_text = text.gsub(
            'ActiveRecord::Associations::Preloader.new.preload',
            'DataCycleCore::PreloadService.preload'
          )
          File.write(f, new_text)
        end

        if File.foreach(f).grep(/to_s\(:/).present?
          text = File.read(f)
          new_text = text.gsub(
            'to_s(:',
            'to_formatted_s(:'
          )
          File.write(f, new_text)
        end

        if File.foreach(f).grep(Regexp.new('ActiveRecord::Base.maintain_test_schema')).present?
          text = File.read(f)
          new_text = text.gsub(
            'ActiveRecord::Base.maintain_test_schema',
            'ActiveRecord.maintain_test_schema'
          )
          File.write(f, new_text)
        end

        manual_action_required.push "[MANUALLY] please replace Rails.application.secrets with corresponding ENV[...] (#{f})" if File.foreach(f).grep(Regexp.new('Rails.application.secrets')).present?

        manual_action_required.push "[MANUALLY] please replace simple_form_for with form_for and replace all f.input with corresponding field helpers (email_field, password_field, text_field) (#{f})" if File.foreach(f).grep(Regexp.new('simple_form_for')).present?

        manual_action_required.push "[MANUALLY] please migrate azure_activedirectory_v2 to entra_id, Migration: https://github.com/RIPAGlobal/omniauth-entra-id/blob/master/UPGRADING.md (#{f})" if File.foreach(f).grep(Regexp.new('azure_activedirectory_v2')).present?
      end

      if manual_action_required.present?
        puts '[MANUAL_ACTION_REQUIRED] The following files require manual action:'
        manual_action_required.each do |mar|
          puts mar
        end
      end

      puts AmazingPrint::Colors.green('[DONE] please check all changes before commiting!')
    end

    desc 'remove some unused config files'
    task clean_configs: :environment do
      file_path = Rails.root.join('config', 'cable.yml')
      if File.exist?(file_path)
        puts 'remove config/cable.yml ...'
        FileUtils.rm_f(file_path)
      end

      file_path = Rails.root.join('config', 'appsignal.yml')
      if File.exist?(file_path)
        puts 'remove config/appsignal.yml ...'
        puts '!!! WARNING: make sure PRODUCTION_ENVIRONMENT in gitlab CI/CD settings includes APPSIGNAL_PUSH_API_KEY !!!' if File.exist?(file_path)
        FileUtils.rm_f(file_path)
      end

      file_path = Rails.root.join('.npmrc')
      if File.exist?(file_path)
        text = File.read(file_path)
        new_text = text.gsub("shamefully-hoist=true\n", '')
        new_text = new_text.gsub("store-dir=/tmp/pnpm/store\n", '')

        if new_text.present?
          if text != new_text
            puts 'remove useless lines from .npmrc ...'
            File.write(file_path, new_text)
          end
        else
          puts 'remove .npmrc ...'
          FileUtils.rm_f(file_path)
        end
      end
    end

    desc 'adjust package.json'
    task adjust_package_json: :environment do
      package_json_path = Rails.root.join('package.json')
      file = File.read(package_json_path)
      pkg_cfg = JSON.parse(file)
      pkg_cfg.deep_merge!({
        'devDependencies' => {
          'data-cycle-core-dev' => 'file:vendor/gems/data-cycle-core/dev_dependencies'
        }
      })

      File.write(package_json_path, "#{JSON.pretty_generate(pkg_cfg)}\n")
    end
  end

  desc 'run all available upgrades'
  task upgrade: :environment do
    # Rake::Task['dc:upgrade:rails71'].invoke
    # Rake::Task['dc:upgrade:rails71'].reenable
    Rake::Task['dc:upgrade:clean_configs'].invoke
    Rake::Task['dc:upgrade:clean_configs'].reenable
    Rake::Task['dc:upgrade:copy_templates'].invoke('global')
    Rake::Task['dc:upgrade:copy_templates'].reenable
    Rake::Task['dc:upgrade:adjust_package_json'].invoke
    Rake::Task['dc:upgrade:adjust_package_json'].reenable
  end
end
