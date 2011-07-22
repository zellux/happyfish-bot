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
end
