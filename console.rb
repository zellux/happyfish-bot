$: << '.'

require 'happyfish'

bot = HappyFishBot.new
# bot.signin
# bot.reload
bot.analyse_user('2221')
# bot.receive_all_boats
# bot.repair_all_buildings
# bot.pick_all_money

scheduler = bot.scheduler
scheduler.add_event(Time.now + 2, Proc.new {puts "Hello world!" }, "Test")
scheduler.dump_events()

while true
  scheduler.do_anything
  sleep(1)
end

