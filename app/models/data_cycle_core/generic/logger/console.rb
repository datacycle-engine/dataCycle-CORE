class DataCycleCore::Generic::Logger::Console

  def initialize(kind)
    @kind = kind
  end

  def preparing_phase(label)
    puts "Preparing  #{label.to_s.gsub(/_/, ' ')} ..."
  end

  def phase_started(label, total = nil)
    puts "#{@kind.capitalize}   #{label.to_s.gsub(/_/, ' ')} ..." if total.nil?
    puts "#{@kind.capitalize}   #{label.to_s.gsub(/_/, ' ')} (#{total} items) ..." if total
  end

  def item_processed(title, id, num, total)
    #puts " -> \"#{title} (\##{id})\" downloaded (#{num} of #{total || '?'})"
  end

  def error(title, id, data, error)
    if title && id
      puts "Error #{@kind}ing \"#{title} (\##{id})\": #{error}"
    elsif title
      puts "Error #{@kind}ing \"#{title}\": #{error}"
    elsif id
      puts "Error #{@kind}ing \"\##{id}\": #{error}"
    else
      puts "Error: #{error}"
    end
    puts "  DATA: #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}" if data
  end

  def info(title, id)
    puts "INFO: #{title} | #{id}"
  end

  def phase_finished(label, total)
    puts "#{@kind.capitalize}ed #{label.to_s.gsub(/_/, ' ')} (#{total} items) ... [DONE]"
  end
end