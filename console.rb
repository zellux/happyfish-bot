$: << '.'

require 'happyfish'

config_file = ARGV[0]
config_file ||= 'config.yml'

config = YAML::load_file(config_file) rescue {}
config['username'] ||= ask('Please enter your username: ')
config['password'] ||= ask('Please enter your password: ') {|q| q.echo = false}

bot = HappyFishBot.new
bot.config = config

at_exit {
  File.open(config_file, 'w') do |out|
    YAML::dump(bot.config, out)
  end
}

bot.signin
bot.reload

scheduler = bot.scheduler
scheduler.add_event(Time.now, bot.method(:refresh_data), "Refresh data")
scheduler.add_event(Time.now + BUILDING_REPAIR_INTERVAL, bot.method(:building_check), "Repair all buildings")
scheduler.dump_events()

while true
  sleep(1)
  scheduler.do_anything
end
