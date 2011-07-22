$: << '.'

require 'happyfish'

bot = HappyFishBot.new
bot.signin
bot.reload

scheduler = bot.scheduler
scheduler.add_event(Time.now, bot.method(:refresh_data), "Refresh data")
scheduler.dump_events()

while true
  if scheduler.remaining_time > 250
    bot.repair_all_buildings
  end
  
  sleep(1)
  scheduler.do_anything
end
