# AppConfigFor

Ruby gem providing Rails::Application#config_for style capabilities for non-rails applications, gems, and rails engines.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'app_config_for'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install app_config_for

## Usage
Presume a typical rails database config at ./config/database.yml  
One environment variable ('MY_APP_ENV', 'RAILS_ENV', or 'RACK_ENV') is set to 'development' or all are non existent.

#### ./config/sample_app.yml
```yml
default: &default
  site: <%= ENV.fetch("MY_APP_SITE", 'www.slackware.com') %>
  password: Slackware#1!

development:
  <<: *default
  username: Linux

test:
  <<: *default
  username: TestingWith

production:
  <<: *default
  username: DefinitelyUsing

shared:
  color: 'Blue'
```

#### sample_application.rb
```ruby
require 'app_config_for'

module Sample
  class App
    extend AppConfigFor
    def info
      puts "Current environment is #{App.env}"
 
      puts "Remote Host: #{App.configured.site}"
 
      # Can access same configuration in other ways
      puts "Username: self.class.config_for(:app)[:username]"
      puts "Password: App.config_for(App).username"
 
      # Access a different config
      if App.config_file?(:database)
        puts "Rails database config: App.config_for(:database)"
      end
    end
  end
end
```

The following shows what can be expected
```ruby
$ irb
3.0.3 :001> require_relative 'my_class'
 => true
3.0.3 :002> example = MyApp::MyClass.new
 => #<MyApp::MyClass:0x000001655ac10460>
3.0.3 :003> example.info
Curent environment is development
Remote Host: www.slackware.com
Username: Linux
Password: Slackware#1!
Color: clear
Rails database config: {:adapter=>"sqlite3", :pool=>5, :timeout=>5000, :database=>"db/development.sqlite3"}
 => nil
3.0.3 :004> exit
$
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ChapterHouse/app_config_for. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/ChapterHouse/app_config_for/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the AppConfigFor project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ChapterHouse/app_config_for/blob/master/CODE_OF_CONDUCT.md).
