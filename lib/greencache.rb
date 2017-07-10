require "greencache/version"
require "fernet"
require "greencache/configuration"

Fernet::Configuration.run do |config|
  config.enforce_ttl = false
end

module Greencache
  class CacheMiss < RuntimeError; end
  class << self
    attr_writer :configuration

    def configure
      yield(configuration)
    end

    def cache(redis_key, config = {}, &block)
      config = merge_config(config)
      return block.call if config[:skip_cache] || !redis_up?
      read_from_cache!(redis_key, config)
    rescue CacheMiss
      value = block.call
      write_into_cache(redis_key, value, config)
      value
    end

    private def read_from_cache!(redis_key, config)
      value = get_value!(redis_key, config)
      log("cache.hit", redis_key, config)
      value
    rescue CacheMiss
      log("cache.miss", redis_key, config)
      raise
    end

    def read_from_cache
      read_from_cache!(redis_key)
    rescue CacheMiss
    end

    def write_into_cache(redis_key, value, config)
      with_redis do
        log("cache.write", redis_key, config)
        set_value(redis_key, value, config)
      end
      value
    end

    private def get_value!(key, config)
      raise CacheMiss unless redis.exists(key)
      decrypt redis.get(key), config
    end

    def get_value(key, config)
      get_value!(key, config)
    rescue CacheMiss
    end

    def set_value(key, value, config)
      redis.setex key, config[:cache_time], encrypt(value, config)
    end

    def merge_config(config)
      configuration.to_hash.merge(config)
    end

    def encrypt(value, config)
      return prep_value(value) unless config[:encrypt]
      fernet.generate(config[:secret], prep_value(value))
    end

    def decrypt(value, config)
      return nil if value.nil?
      return MultiJson.load(value) unless config[:encrypt]
      verifier = fernet.verifier(config[:secret], value)
      return MultiJson.load(verifier.message) if verifier.valid?
      return nil
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def redis
      configuration.redis
    end

    def redis_up?
      begin
        redis.ping
      rescue Redis::CannotConnectError, Timeout::Error
        puts "Redis is DOWN! :shitsonfire:"
        return false
      end
      return true
    end

    def with_redis(&block)
      block.call if redis_up?
    end

    def test?
      ENV["RACK_ENV"] == 'test'
    end

    def prep_value(value)
      MultiJson.encode(value)
    end

    def log(str, key, config)
      config[:logger].log(log_prefix(str, config) => 1, :key => key) unless config[:silent]
    end

    def log_prefix(str, config)
      [config[:log_prefix], str].join(".")
    end

    def fernet
      ::Fernet
    end
  end
end
