# Greencache

A gem for caching data in Redis.

This gem caches data from slow services in Redis

This gem is also able to encrypt the cached results with Fernet if required.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'greencache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install greencache

## Usage

```ruby

Greencache.configure do |c|
  c.redis = $redis
  c.secret = <some_long_hash>
  c.encrypt = true
end

value = Greencache.cache "unique_cache_key" do
  call_to_slow_service
end
```

### Configuration

Several configuration options are available to use that defined the behaviour of
greencache.

<table>
  <tr>
    <td>:redis</td>
    <td>Connection to redis</td>
  </tr>
  <tr>
    <td>:secret</td>
    <td>If encrypting, what secret should be used.  See [Fernet](https://github.com/fernet/fernet-rb) README for more
information</td>
  </tr>
  <tr>
    <td>:encrypt</td>
    <td>Should cached data be encrypted (boolean)</td>
  </tr>
  <tr>
    <td>:skip_cache</td>
    <td>Should the cache be skipped.  Useful in test environments (boolean)</td>
  </tr>
  <tr>
    <td>:logged</td>
    <td>Standard logger object to use for logging</td>
  </tr>
  <tr>
    <td>:log_prefix</td>
    <td>String to prefix to l2met compatible log lines</td>
  </tr>
  <tr>
    <td>:cache_time</td>
    <td>Time (in seconds) to cache data for before expiring</td>
  </tr>
</table>

## Testing

Specs to come ;)

## Contributing

1. Fork it ( https://github.com/neilmiddleton/greencache/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
