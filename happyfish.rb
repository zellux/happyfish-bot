require 'yaml'
require 'highline/import'

def prompt_and_get(hint)
  STDOUT.write(hint)
  gets
end
  
config = YAML::load_file('config.yml') rescue {}
config['username'] ||= ask('Please enter your username: ')
config['password'] ||= ask('Please enter your password: ') {|q| q.echo = false}

at_exit {
  File.open('config.yml', 'w') do |out|
    YAML::dump(config, out)
  end
}
