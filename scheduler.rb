require 'ostruct'
require 'logger'
require 'set'

class Scheduler
  def initialize(bot)
    @bot = bot
    @events = []
    @event_keys = Set.new
    @log = Logger.new(STDERR)
  end

  def add_event(time, proc, title="", uid="")
    return if not title.empty? and @event_keys.include? title
    event = OpenStruct.new
    event.time = time
    event.proc = proc
    event.title = title
    event.uid = uid
    @events << event
    @event_keys.add title
    @events.sort! {|x,y| [x.time, x.title] <=> [y.time, y.title] }
  end

  def next_event
    @events[0]
  end

  def dump_events
    @log.info '-' * 20
    @events.each {|e| @log.info "#{e.title} at #{e.time}" }
    @log.info '-' * 20
  end

  def do_anything
    did = false
    while Time.now > @events[0].time
      event = @events.shift
      @event_keys.delete event.title
      # @log.info "Working on #{event.title}"
      ret = event.proc.call
      if ret.class == Hash and ret['money'] == 0 and @bot.myself?(event.uid)
        # Cannot pick any money, do it again 5 seconds later!
        @log.info "Failed to #{event.title}, do it again in 5 seconds"
        add_event(Time.now + 5, event.proc, event.title)
      end
      
      did = true
    end
    if did and not @events.empty?
      @log.info "Next event will be handled #{(@events[0].time - Time.now).to_i} seconds later"
    end
  end

  def remaining_time
    next_event.time - Time.now
  end
end
