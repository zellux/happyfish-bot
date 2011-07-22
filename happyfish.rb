# -*- coding: utf-8 -*-
$: << '.'

require 'yaml'
require 'highline/import'
require 'sina'
require 'logger'
require 'json'

def export_json(json, filename)
  File.open(filename, 'w') do |out|
    out.write(JSON.pretty_generate(json))
  end
end

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
    export_json(@island_info, 'island.yml')
  end

  def pick_single_money(uid, item)
    own = uid == @user_info['user']['uid']
    if own
      req = @agent.post("http://wbisland.hapyfish.com/api/harvestplant?ts=#{Time.now.to_i}050", "itemId" => item)
    else
      req = @agent.post("http://wbisland.hapyfish.com/api/moochplant", "fid" => uid, "itemId" => item)
    end
    response = JSON.parse(req.body)
    exp = response['expChange'].to_s.to_i rescue 0
    coin = response['coinChange'].to_s.to_i rescue 0
    [exp, coin]
  end
  
  def pick_money(uid = nil)
    req = @agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
    island = JSON.parse(req.body)
    File.open('friend.yml', 'w').write(JSON.pretty_generate(island))
    expsum = coinsum = 0
    island['islandVo']['buildings'].select{|x| x['deposit'] && x['deposit'].to_i > 0 }.each do |item|
      next if uid != @user_info['user']['uid'] and item['hasSteal'] == 1
      exp, coin = pick_single_money(uid, item['id'])
      expsum += exp
      coinsum += coin
    end
    @log.info "Received #{expsum} EXP, #{coinsum} coins from island ##{uid}"
  end

  def pick_all_money
    @friends_info['friends'].each do |f|
      pick_money(f['uid'].to_s)
    end
  end

  def receive_single_boat(uid, pos)
    own = uid == @user_info['user']['uid']
    if own
      req = @agent.post("http://wbisland.hapyfish.com/api/receiveboat", "positionId" => pos)
    else
      req = @agent.post("http://wbisland.hapyfish.com/api/moochvisitor", "ownerUid" => uid, "positionId" => pos)
    end
    response = JSON.parse(req.body)
    response['expChange'].to_s.to_i rescue 0
  end

  def receive_boats(uid)
    req = @agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
    island = JSON.parse(req.body)
    expsum = 0
    island['dockVo']['boatPositions'].select{|x| x['state'] == 'arrive_1' }.each do |item|
      next if uid != @user_info['user']['uid'] and item['canSteal'] != 1
      exp = receive_single_boat(uid, item["id"])
      expsum += exp
    end
    @log.info "Received #{expsum} EXP by picking up visitors from island ##{uid}"
  end

  def receive_all_boats
    @friends_info['friends'].each do |f|
      receive_boats(f['uid'].to_s)
    end
  end
  
  def repair_single_building(uid, item, event)
    req = @agent.post("http://wbisland.hapyfish.com/api/manageplant", "ownerUid" => uid, "itemId" => item, "eventType" => event)
    response = JSON.parse(req.body)
    puts response
    response['resultVo']['expChange'].to_s.to_i rescue 0
  end
  
  def repair_buildings(uid)
    req = @agent.post("http://wbisland.hapyfish.com/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
    island = JSON.parse(req.body)
    expsum = 0
    # export_json(island, 'friend.yml')
    island['islandVo']['buildings'].select{|x| x['event'] && x['event'] == 1 }.each do |item|
      exp = repair_single_building(uid, item['id'], 1)
      expsum += exp
    end
    @log.info "Received #{expsum} EXP by reparing buildings in island ##{uid}"
  end

  def repair_all_buildings
    @friends_info['friends'].each do |f|
      repair_buildings(f['uid'].to_s)
    end
  end
end
  
bot = HappyFishBot.new
bot.signin
bot.reload
bot.receive_all_boats
bot.repair_all_buildings
bot.pick_all_money
