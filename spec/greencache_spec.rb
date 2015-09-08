require 'spec_helper'
require 'fernet'
require 'logger'
require 'multi_json'

Greencache.configure do |c|
  c.redis = Redis.new
  c.logger = Logger.new(StringIO.new)
  c.silent = true
end

class Dummy
  def self.uuid
    SecureRandom.uuid
  end

  def self.run
    Greencache.cache "foo" do
      get_value
    end
  end

  def self.get_value
    "bar"
  end
end

describe Greencache do
  let(:rc) { Greencache }
  let(:config) { Greencache.configuration }

  before do
    allow(rc.fernet).to receive(:generate){ "abd" }
  end

  context 'when skipping caching' do
    before do
      config.skip_cache = true
    end

    it 'does not use the cache' do
      expect(rc).to_not receive(:read_from_cache)
      Dummy.run
    end
  end

  context 'when caching' do
    before do
      config.skip_cache = false
    end

    it 'uses the cached' do
      expect(rc).to receive(:read_from_cache!){ {} }
      Dummy.run
    end

    it 'shows redis as down if it times out' do
      allow(rc.redis).to receive(:ping){ raise Timeout::Error }
      expect(rc.redis_up?).to eq(false)
    end

    it 'skips cache when redis is down' do
      allow(rc).to receive(:redis_up?){ false }
      expect(rc).to_not receive(:read_from_cache)
      expect(Dummy).to receive(:get_value){ "bar" }
      Dummy.run
    end

  end

  describe 'configuration' do
    it 'respects cache_time' do
      config.cache_time = 100
      expect(rc.cache_time).to eq(100)
    end

    it 'respects skip_cache' do
      config.skip_cache = true
      expect(rc.skip_cache?).to eq(true)
    end

    it 'knows the secret' do
      config.secret = "bar"
      expect(rc.secret).to eq("bar")
    end
  end

  it 'can write into the cache' do
    p = Proc.new { "" }
    expect(rc).to receive(:set_value).with("foo", "", cache_time: nil)
    rc.write_into_cache("foo", p.call)
  end


  it 'respects cache time passed in arguments' do
    p = Proc.new { "" }
    expect(rc).to receive(:set_value).with("foo", "", cache_time: 10)
    rc.write_into_cache("foo", p.call, cache_time: 10)
  end

  it "can get a value that's been set" do
    rc.redis.set "foo", "bar"
    expect(rc.redis).to receive(:get).with("foo"){ "bar" }
    expect(rc).to receive(:decrypt).with("bar")
    rc.get_value("foo")
  end

  it 'can set a value' do
    config.cache_time = 100
    config.encrypt = false
    expect(rc.redis).to receive(:setex).with("foo", 100, '"bar"')
    rc.set_value("foo", "bar")
  end

  it 'can set a value with cache time' do
    config.cache_time = 100
    config.encrypt = false
    expect(rc.redis).to receive(:setex).with("foo", 10, '"bar"')
    rc.set_value("foo", "bar", cache_time: 10)
  end

  it 'encrypts' do
    config.encrypt = true
    config.secret = "foo"
    expect(rc.fernet).to receive(:generate).with("foo", '"bar"'){ "abc" }
    rc.encrypt("bar")
  end
end
