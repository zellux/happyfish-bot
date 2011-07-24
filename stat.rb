#!/usr/bin/env ruby

money = {}
exp = {}

File.open('log/stat.log', 'r') do |log|
  log.each_line do |line|
    info = line[/-- : (.*)/, 1]
    next if not info
    type, e, m, uid = info.split ', '
    money[type] ||= 0
    exp[type] ||= 0
    money[type] += m.to_i
    exp[type] += e.to_i
  end
end

puts "Money: #{money}"
puts "EXP: #{exp}"
