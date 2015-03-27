module Greencache
  class Configuration
    attr_accessor :redis
    attr_accessor :secret
    attr_accessor :cache_time
    attr_accessor :encrypt
    attr_accessor :skip_cache
    attr_accessor :silent
    attr_accessor :logger
    attr_accessor :log_prefix

    def initialize
      @cache_time = 600
      @encrypt = false
      @secret = nil
      @skip_cache = false
      @silent = false
      @logger = nil
      @log_prefix = "greencache"
    end
  end
end
