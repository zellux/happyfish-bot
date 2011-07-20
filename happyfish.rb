# -*- coding: utf-8 -*-
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
      @log.info 'Logging into sina weibo ...'
      login(@agent, @config['username'], @config['password'])
      html = @agent.get('http://game.weibo.com/happyisland?origin=1026').body
      url = html[/iframe\s+src="(.*?)"/, 1]
      @config['session'] ||= url
    end
    
    @log.info 'Logging into happy fish game ...'
    req = @agent.get(@config['session'])
    if req.body[/problem1.gif/]
      @config['session'] = nil
      signin
    end
  end

  def reload
    @log.info 'Loading user data ...'
    req = @agent.post("http://wbisland.hapyfish.com/api/inituserinfo", "first" => "1")
    @user_info = JSON.parse(req.body)
    req = @agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => @user_info['user']['uid'])
    @island_info = JSON.parse(req.body)
    req = @agent.post("http://wbisland.hapyfish.com/api/getfriends", "pageIndex" => "1", "pageSize" => 350000)
    @friends_info = JSON.parse(req.body)
  end

  def pick_money(uid = nil)
    own = uid == @user_info['user']['uid']
    uid ||= @user_info['user']['uid']
    req = @agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
    island = JSON.parse(req.body)
    File.open('friend.yml', 'w').write(JSON.pretty_generate(island))
    expsum = coinsum = 0
    island['islandVo']['buildings'].select{|x| x['deposit'] && x['deposit'].to_i > 0 }.each do |item|
      if own
        req = @agent.post("http://wbisland.hapyfish.com/api/harvestplant?ts=#{Time.now.to_i}050", "itemId" => item["id"])
      else
        next if item['hasSteal'] == 1
        req = @agent.post("http://wbisland.hapyfish.com/api/moochplant", "fid" => uid, "itemId" => item["id"])
      end
      response = JSON.parse(req.body)
      exp = response['expChange'].to_s.to_i rescue 0
      coin = response['coinChange'].to_s.to_i rescue 0
      expsum += exp
      coinsum += coin
    end
    @log.info "Received #{expsum} EXP, #{coinsum} coins from island ##{uid}"
  end

  def receive_all_boats
    @log.info 'Receiving all boats'
    @island_info['dockVo']['boatPositions'].select{|x| x['state'] == 'arrive_1' }.each do |item|
      req = @agent.post("http://wbisland.hapyfish.com/api/receiveboat", "positionId" => item["id"])
    end
  end

  def repair_all_buildings
    @log.info 'Repairing all buildings'
    @island_info['islandVo']['buildings'].select{|x| x['event'] && x['event'] == 1 }.each do |item|
      req = @agent.post("http://wbisland.hapyfish.com/api/manageplant", "ownerUid" => @user_info['user']['uid'], "itemId" => item['id'], "eventType" => 1)
    end
  end

  def pick_all_money
    @friends_info['friends'].each do |f|
      pick_money(f['uid'].to_s)
    end
  end
end
  
bot = HappyFishBot.new
bot.signin
bot.reload
bot.receive_all_boats
bot.repair_all_buildings
bot.pick_all_money
