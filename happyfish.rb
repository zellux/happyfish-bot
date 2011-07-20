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
    if not @config['session']
      @log.info('Logging into sina weibo ...')
      login(@agent, @config['username'], @config['password'])
      html = @agent.get('http://game.weibo.com/happyisland?origin=1026').body
      url = html[/iframe\s+src="(.*?)"/, 1]
      @config['session'] ||= url
    end
    
    @log.info('Logging into happy fish game ...')
    html = @agent.get(url).body
  end

  def reload
    @log.info('Loading user data ...')
    req = @agent.post("http://wbisland.hapyfish.com/api/inituserinfo", "first" => "1")
    @user_info = JSON.parse(req.body)
    req = @agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => @user_info['user']['uid'])
    @island_info = JSON.parse(req.body)
  end

  def pick_own_money()
    @log.info('Picking up own money ...')
    expsum = coinsum = 0
    @island_info['islandVo']['buildings'].select{|x|x['deposit']}.each do |item|
      req = @agent.post("http://wbisland.hapyfish.com/api/harvestplant?ts=#{Time.now.to_i}050", "itemId" => item["id"])
      response = JSON.parse(req.body)
      exp = response['expChange'].to_i rescue 0
      coin = response['coinChange'].to_i rescue 0
      expsum += exp
      coinsum += coin
    end
    puts "Received #{expsum} EXP, #{coinsum} coins"
  end
  
end

bot = HappyFishBot.new
bot.signin
bot.reload
bot.pick_own_money
