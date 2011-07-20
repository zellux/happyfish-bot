$: << '.'

require 'yaml'
require 'highline/import'
require 'sina'
require 'logger'
require 'json'

class HappyFishBot
  def initialize
    @config = YAML::load_file('config.yml') rescue {}
    @config['username'] ||= ask('Please enter your username: ')
    @config['password'] ||= ask('Please enter your password: ') {|q| q.echo = false}
    at_exit {
      File.open('config.yml', 'w') do |out|
        YAML::dump(@config, out)
      end
    }

    @agent = Mechanize.new { |agent|
      agent.user_agent_alias = 'Mac Safari'
    }

    @log = Logger.new(STDOUT)
  end
  
  def signin
    @log.info('Logging into sina weibo...')
    login(@agent, @config['username'], @config['password'])
    
    @log.info('Logging into happy fish game...')
    html = @agent.get('http://game.weibo.com/happyisland?origin=1026').body
    url = html[/iframe\s+src="(.*?)"/, 1]
    html = @agent.get(url).body
  end

  def reload
    req = @agent.post("http://wbisland.hapyfish.com/api/inituserinfo", "first" => "1")
    @userinfo = JSON.parse(req.body)
    puts @userinfo
  end
end

bot = HappyFishBot.new
bot.signin
bot.reload

