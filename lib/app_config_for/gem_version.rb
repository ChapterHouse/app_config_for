module AppConfigFor

  # Current version of this gem with comparable values.
  # @return [Gem::Version]
  def self.gem_version
    Gem::Version.new(VERSION::STRING)
  end

  # The rendition
  module VERSION
    MAJOR = 0 # A field-grade officer
    MINOR = 0 # When the semitones show up as intervals between the 2nd and 3rd degrees
    TINY  = 6 # The number of people who use antidisestablishmentarianism in everyday conversation
    PRE = 2   # Ante not auntie

    # String form of the version (duh). Are you seriously reading this? I guess it is slightly more interesting that Moby-Dick.
    STRING = [MAJOR, MINOR, TINY, PRE].compact.join('.') 
  end

end
