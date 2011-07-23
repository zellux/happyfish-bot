# -*- coding: utf-8 -*-
$: << '.'

require 'yaml'
require 'highline/import'
require 'sina'
require 'logger'
require 'json'
require 'scheduler'

API_ROOT = "http://t.happyfishgame.com.cn"

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
      agent.user_agent_alias = 'Windows Mozilla'
    }

    # @agent.set_proxy('127.0.0.1', 8080)
    @log = Logger.new(STDERR)
    @scheduler = Scheduler.new
    @friends_list = Hash.new
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
      @log.info 'Session data outdated, creating new session ...'
      @config['session'] = nil
      signin
      return
    end
  end

  def reload(again=false)
    @log.info 'Loading user data ...'
    req = @agent.post("#{API_ROOT}/api/inituserinfo", "first" => "1")
    @user_info = JSON.parse(req.body)
    export_json(@user_info, 'userinfo.yml')
    if @user_info['status'] == '-1'
      if again
        throw "Failed to load user data"
      end
      @config['session'] = nil
      signin
      reload(true)
    end
    
    req = @agent.post("#{API_ROOT}/api/getfriends", "pageIndex" => "1", "pageSize" => 350000)
    @friends_info = JSON.parse(req.body)
    export_json(@friends_info, 'friend.yml')
    @friends_info['friends'].each do |f|
      @friends_list[f['uid']] = f['name']
    end
  end

  def pick_single_money(uid, item)
    own = uid == @user_info['user']['uid']
    if own
      req = @agent.post("#{API_ROOT}/api/harvestplant?ts=#{Time.now.to_i}050", "itemId" => item)
    else
      req = @agent.post("#{API_ROOT}/api/moochplant", "fid" => uid, "itemId" => item)
    end
    response = JSON.parse(req.body)
    exp = response['expChange'].to_s.to_i rescue 0
    coin = response['coinChange'].to_s.to_i rescue 0
    @log.info "Received #{exp} EXP, #{coin} coins from island #{@friends_list[uid]} ##{uid}"
    [exp, coin]
  end
  
  def pick_money(uid = nil)
    req = @agent.post("#{API_ROOT}/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
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
      req = @agent.post("#{API_ROOT}/api/receiveboat", "positionId" => pos)
    else
      req = @agent.post("#{API_ROOT}/api/moochvisitor", "ownerUid" => uid, "positionId" => pos)
    end
    response = JSON.parse(req.body)
    exp = response['result']['expChange'].to_s.to_i rescue 0
    @log.info "Received #{exp} EXP by picking up visitors from island #{@friends_list[uid]} ##{uid}"
    exp
  end

  def receive_boats(uid)
    req = @agent.post("#{API_ROOT}/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
    island = JSON.parse(req.body)
    expsum = 0
    island['dockVo']['boatPositions'].select{|x| x['state'] == 'arrive_1' }.each do |item|
      next if uid != @user_info['user']['uid'] and not item['canSteal']
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
    req = @agent.post("#{API_ROOT}/api/manageplant", "ownerUid" => uid, "itemId" => item, "eventType" => event)
    response = JSON.parse(req.body)
    puts response
    exp = response['resultVo']['expChange'].to_s.to_i rescue 0
    @log.info "Received #{exp} EXP by reparing buildings in island #{@friends_list[uid]} ##{uid}"
    exp
  end
  
  def repair_buildings(uid)
    req = @agent.post("#{API_ROOT}/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
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

  def analyse_user(uid)
    req = @agent.post("#{API_ROOT}/api/initisland?ts=#{Time.now.to_i}050", "ownerUid" => uid)
    own = uid == @user_info['user']['uid']
    island = JSON.parse(req.body)
    export_json(island, "island.yml")
    time = Time.now
    island['dockVo']['boatPositions'].each do |item|
      remaining = item['time']
      next if not remaining or not item['canSteal'] or (not own and item['visitorNum'] <= 1)
      remaining = -remaining
      title = "Pick visitors #{item['id']} from #{uid}"
      if remaining <= 0
        @scheduler.add_event(time, Proc.new {receive_single_boat(uid, item['id']) }, title)
      else
        @scheduler.add_event(time + remaining, Proc.new {receive_single_boat(uid, item['id']) }, title)
      end
    end

    island['islandVo']['buildings'].each do |item|
      remaining = item['payRemainder']
      deposit = item['deposit'].to_s.to_i rescue 0
      title = "Pick money #{item['id']} from #{uid}"
      next if not remaining or deposit <= 0 or (not own and (item['hasSteal'] == true or item['hasSteal'] == 1))
      if remaining <= 0
        @scheduler.add_event(time, Proc.new {pick_single_money(uid, item['id']) }, title)
      else
        @scheduler.add_event(time + remaining, Proc.new {pick_single_money(uid, item['id']) }, title)
      end
    end
  end

  def analyse_all_users
    @friends_info['friends'].each do |f|
      analyse_user(f['uid'].to_s)
    end
  end

  def refresh_data
    # repair_all_buildings
    analyse_all_users
    @scheduler.add_event(Time.now + 1800, method(:refresh_data), "Refresh data")
  end

  attr_reader :scheduler
end

