# frozen_string_literal: true

namespace :dc do
  namespace :upgrade do
    desc 'override some files in project from core templates'
    task rails_7_1: :environment do # rubocop:disable Naming/VariableNumber
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

        manual_action_required.push "[MANUALLY] please replace simple_form_for with form_for and replace all f.input with corresponding field helpers (#{f})" if File.foreach(f).grep(Regexp.new('simple_form_for')).present?

        manual_action_required.push "[MANUALLY] please migrate azure_activedirectory_v2 to entra_id, Migration: https://github.com/RIPAGlobal/omniauth-entra-id/blob/master/UPGRADING.md (#{f})" if File.foreach(f).grep(Regexp.new('azure_activedirectory_v2')).present?
      end

      if manual_action_required.present?
        puts '[MANUAL_ACTION_REQUIRED] The following files require manual action:'
        manual_action_required.each do |mar|
          puts mar
        end
      end

      puts '[DONE] please check all changes before commiting!'
    end
  end
end
