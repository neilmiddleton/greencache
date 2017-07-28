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

  context 'merging the configuration' do

    it 'keeps the global config' do
      config.skip_cache = true

      config = rc.merge_config({})
      expect(config).to be_a(Hash)
      expect(config[:skip_cache]).to eql(true)
    end

    it 'overrides provided values' do
      config.skip_cache = true

      config = rc.merge_config({skip_cache: false})
      expect(config).to be_a(Hash)
      expect(config[:skip_cache]).to eql(false)
    end
  end

  it 'can write into the cache' do
    p = Proc.new { "" }
    config = rc.merge_config({})
    expect(rc).to receive(:set_value).with("foo", "", config)
    rc.write_into_cache("foo", p.call, config)
  end

  it "can get a value that's been set" do
    rc.redis.set "foo", "bar"
    expect(rc.redis).to receive(:get).with("foo"){ "bar" }
    expect(rc).to receive(:decrypt).with("bar", {encrypt: true})
    rc.get_value("foo", {encrypt: true})
  end

  it 'can set a value' do
    expect(rc.redis).to receive(:setex).with("foo", 100, '"bar"')
    rc.set_value("foo", "bar", {cache_time: 100, encrypt: false})
  end

  it 'encrypts' do
    expect(rc.fernet).to receive(:generate).with("foo", '"bar"'){ "abc" }
    rc.encrypt("bar", {encrypt: true, secret: 'foo'})
  end

  context "with a key_prefix" do
    let(:config) do
      {cache_time: 100, encrypt: false, key_prefix: "key_namespace:"}
    end

    it "uses the key_prefix when writing" do
      expect(rc.redis).to receive(:setex).with("key_namespace:foo", 100, '"bar"')
      rc.set_value("foo", "bar", config)
    end

    it "uses the key_prefix when reading" do
      rc.redis.set "key_namespace:foo", "bar"
      expect(rc.redis).to receive(:get).with("key_namespace:foo"){ "bar" }
      expect(rc).to receive(:decrypt).with("bar", config)
      rc.get_value("foo", config)
    end
  end
end
