require 'ostruct'
require 'logger'

class Scheduler
  def initialize
    @events = []
    @log = Logger.new(STDERR)
  end

  def add_event(time, proc, title="")
    event = OpenStruct.new
    event.time = time
    event.proc = proc
    event.title = title
    @events << event
    @events.sort! {|x,y| x.time <=> y.time }
  end

  def next_event
    events[0]
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
      @log.info "Working on #{event.title}"
      event.proc.call
      did = true
    end
    if did and not @events.empty?
      dump_events
      @log.info "Next event will be handled #{(@events[0].time - Time.now).to_i} seconds later"
    end
  end
end
