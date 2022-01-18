# frozen_string_literal: true

namespace :dc do
  namespace :info do
    task :dependencies_gems do
      puts Gem.loaded_specs.values.map { |g| 
        g.licenses.map { |l|
          [g.name, g.version.to_s, l]
        }
      }.reduce([], :+).sort_by(&:first)
      .map { |row|
        row.join(', ')
      }
    end
    
    task :dependencies_yarn do
      package_list = `npm list --all`.split("\n").map { |line| 
        line.gsub(/^[^\w@]*/, '').gsub(/ deduped$/, '')
      }.reject { |line|
        line =~ /UNMET OPTIONAL DEPENDENCY/ || line =~ /UNMET DEPENDENCY/ || line =~ /data-cycle-/
      }

      puts package_list.map { |package|
        JSON.parse(`npm info #{package} --json`)
      }.map { |details|
        [details['name'], details['version'], details['license']]
      }.sort_by(&:first).map { |row|
        row.join(', ')
      }.uniq
    end
  end
end
  