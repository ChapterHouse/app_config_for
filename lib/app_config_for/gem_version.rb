module AppConfigFor

  def self.gem_version
    Gem::Version.new(VERSION::STRING)
  end

  module VERSION
    MAJOR = 0
    MINOR = 0
    TINY  = 4
    PRE = 0

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.')
  end

end
