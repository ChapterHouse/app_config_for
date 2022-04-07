module AppConfigFor
  class Error < StandardError; end

  class ConfigNotFound < Error

    attr_reader :locations_searched, :original_exception

    def initialize(locations, original_exception)
      @locations_searched = Array(locations).map { |x| Pathname(x).expand_path }
      @original_exception = original_exception
      super "Could not locate configuration at: #{@locations_searched.join(' or ')}"
    end
  end

  class LoadError < Error

    attr_reader :file, :original_exception

    def initialize(file, original_exception)
      @file = Pathname(file).expand_path
      @original_exception = original_exception
      super "Could not load configuration file: #{@file}\n#{@original_exception.message}"
    end
  end
end
