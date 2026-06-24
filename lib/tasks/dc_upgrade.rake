# frozen_string_literal: true

namespace :dc do
  namespace :upgrade do
    desc 'copy core templates to project'
    task :copy_templates, [:folder, :override] => :environment do |_, args|
      abort('Please provide a folder name') if args.folder.nil?

      project_path = Rails.root
      template_path = DataCycleCore::Engine.root.join('lib/templates', args.folder)

      Dir.glob(template_path.join('**', '*'), File::FNM_DOTMATCH).each do |f|
        next unless File.file?(f)

        file_name = File.basename(f, '.template')
        file_path = File.dirname(f)
        dest_path = project_path.join(file_path.gsub(template_path.to_s, '').delete_prefix(File::SEPARATOR))
        dest_file = dest_path.join(file_name)

        # Skip if destination file is newer and override is not true
        next if File.exist?(dest_file) && File.mtime(dest_file) >= File.mtime(f) && args.override.to_s != 'true'

        FileUtils.mkdir_p(dest_path)
        FileUtils.cp(f, dest_file)
      end
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

      file_path = Rails.public_path.join('favicon.ico')
      if File.exist?(file_path)
        print 'remove public/favicon.ico ... '
        FileUtils.rm_f(file_path)
        puts AmazingPrint::Colors.green('✔')
      end

      file_path = Rails.public_path.join('apple-touch-icon-precomposed.png')
      if File.exist?(file_path)
        print 'remove public/apple-touch-icon-precomposed.png ... '
        FileUtils.rm_f(file_path)
        puts AmazingPrint::Colors.green('✔')
      end

      file_path = Rails.public_path.join('apple-touch-icon.png')
      if File.exist?(file_path)
        print 'remove public/apple-touch-icon.png ... '
        FileUtils.rm_f(file_path)
        puts AmazingPrint::Colors.green('✔')
      end

      file_path = Rails.root.join('config', 'content_security_policy.rb')
      if File.exist?(file_path)
        print 'remove config/content_security_policy.rb ... '
        FileUtils.rm_f(file_path)
        puts AmazingPrint::Colors.green('✔')
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

    desc 'init .rubocop_todo.yml'
    task init_rubocop_todo: :environment do
      rubocop_todo_path = Rails.root.join('.rubocop_todo.yml')

      unless File.exist?(rubocop_todo_path)
        print 'Initializing .rubocop_todo.yml ... '
        FileUtils.touch(rubocop_todo_path)
        puts AmazingPrint::Colors.green('✔')
      end
    end

    desc ' fix SuperAdmin Role in seeds.rb for internal admin'
    task fix_super_admin_role: :environment do
      seeds_path = Rails.root.join('db', 'seeds.rb')
      file = File.read(seeds_path)
      new_file = file.gsub('role_id: DataCycleCore::Role.order(rank: :desc).first.id', 'role_id: DataCycleCore::Role.super_admin.id')
      new_file = new_file.gsub("role_id: DataCycleCore::Role.order('rank DESC').first.id", 'role_id: DataCycleCore::Role.super_admin.id')

      if file != new_file
        print 'Fixing SuperAdmin Role in seeds.rb ... '
        File.write(seeds_path, new_file)
        puts AmazingPrint::Colors.green('✔')
      end
    end
  end

  desc 'run all available upgrades'
  task upgrade: :environment do
    Rake::Task['dc:upgrade:clean_configs'].invoke
    Rake::Task['dc:upgrade:clean_configs'].reenable
    Rake::Task['dc:upgrade:copy_templates'].invoke('global')
    Rake::Task['dc:upgrade:copy_templates'].reenable
    # rails 8.1 upgrade
    Rake::Task['dc:upgrade:copy_templates'].invoke('rails_8_1')
    Rake::Task['dc:upgrade:copy_templates'].reenable
    Rake::Task['dc:upgrade:adjust_package_json'].invoke
    Rake::Task['dc:upgrade:adjust_package_json'].reenable
    Rake::Task['dc:upgrade:init_rubocop_todo'].invoke
    Rake::Task['dc:upgrade:init_rubocop_todo'].reenable
    Rake::Task['dc:upgrade:fix_super_admin_role'].invoke
    Rake::Task['dc:upgrade:fix_super_admin_role'].reenable
  end
end
