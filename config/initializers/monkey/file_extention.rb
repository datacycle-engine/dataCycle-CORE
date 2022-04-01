# frozen_string_literal: true

class File
  def each_chunk(token)
    regexp = Regexp.new("(.*)(#{token}.*)")

    chunk = nil

    each do |line|
      if line =~ regexp # rubocop:disable Performance/RegexpMatch
        if chunk
          chunk += line.gsub(regexp, '\1')

          yield chunk
        end

        chunk = line.gsub(regexp, '\2')
      elsif chunk
        chunk += line
      end
    end
    yield chunk
  end
end
