$: << '.'

require 'yaml'
require 'highline/import'
require 'sina'
require 'logger'
require 'json'

$LOG = Logger.new(STDOUT)

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

$agent = Mechanize.new { |agent|
  agent.user_agent_alias = 'Mac Safari'
}

$LOG.info('Logging into sina weibo...')
login($agent, config['username'], config['password'])

$LOG.info('Getting happy fish game url...')
html = $agent.get('http://game.weibo.com/happyisland?origin=1026').body

url = html[/iframe\s+src="(.*?)"/, 1]
$LOG.info("Loading #{url}...")
html = $agent.get(url).body

req = $agent.post("http://wbisland.hapyfish.com/api/inituserinfo", "first" => "1")
json = JSON.parse(req.body)

puts json

# req = $agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}000",
#             '
