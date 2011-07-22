require 'ostruct'

class Scheduler
  def initialize
    @events = []
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
    @events.each {|e| puts "#{e.title} at #{e.time}" }
  end

  def do_anything
    did = false
    while Time.now > @events[0].time
      event = @events.shift
      event.proc.call
      did = true
    end
    if did and not @events.empty?
      puts "Next event will be handled #{(@events[0].time - Time.now).to_i} seconds later"
    end
  end
end
