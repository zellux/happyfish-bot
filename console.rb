$: << '.'

require 'happyfish'

bot = HappyFishBot.new
bot.signin
bot.reload

scheduler = bot.scheduler
scheduler.add_event(Time.now, bot.method(:refresh_data), "Refresh data")
scheduler.dump_events()

while true
  sleep(1)
  scheduler.do_anything
end
