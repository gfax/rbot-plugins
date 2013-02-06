#-- vim:sw=2:et
#++
#
# :title: Dates
#
# Author:: Lite <degradinglight@gmail.com>
# Copyright:: (C) 2012 gfax.ch
# License:: GPL
#
class DatesPlugin < Plugin

  def help(plugin, topic="")
    return "Returns days until/since event. !date <year> <month> <day>; Other triggers: !gfax, !gfaqs, !magfest, !newyear, !obb, !tds, !xmas, !2012"
  end

  def comp(m, params)
    if params[:hour].nil? then hour = 0 else hour = params[:hour] end
    event = Time.new(params[:year],params[:month],params[:day],hour,0,0)
    # returns an array with number of days, hours, minutes and seconds.
    days, remaining = (Time.now-event).to_i.abs.divmod(86400)
    hours, remaining = remaining.divmod(3600)
    minutes, seconds = remaining.divmod(60)
    [days, hours, minutes, seconds]
    years = 0
    while days >= 365
      years += 1
      days -= 365
      end
    days += years / 4 # leapdays
    if years == 0 then ys = "" else ys = "#{years} years, " end
    if days == 0 then ds = "" else ds = "#{days} days, " end
    if hours == 0 then hs = "" else hs = "#{hours} hours, " end
    if minutes == 0 then ms = "" else ms = "#{minutes} minutes " end
    if seconds == 0 then ss = "." else ss = "and #{seconds} seconds." end
    if params[:hour].nil?
      m.reply "#{ys}#{days} days."
     else
      m.reply ys + ds + hs + ms + ss
     end
  end

end

plugin = DatesPlugin.new
plugin.map "date [:year [:month [:day [:hour]]]]", :action => 'comp', :defaults => { :year => Time.now.year, :month => Time.now.month, :day => Time.now.day + 1 }
plugin.map "gfaqs", :action => 'comp', :defaults => { :year => 2002, :month => 07, :day => 02 }
plugin.map "gfax", :action => 'comp', :defaults => { :year => 2003, :month=> 06, :day => 03 }
plugin.map "magfest", :action => 'comp', :defaults => { :year => 2012, :month => 01, :day => 05 }
plugin.map "newyear", :action => 'comp', :defaults => { :year => Time.now.year + 1, :month => 01, :day => 01 }
plugin.map "obb", :action => 'comp', :defaults => { :year => 2012, :month => 1, :day => 30 }
plugin.map "tds", :action => 'comp', :defaults => { :year => 1993, :month => 06, :day => 23 }
plugin.map "xmas", :action => 'comp', :defaults => { :year => Time.now.year, :month => 12, :day => 25 }
plugin.map "2012", :action => 'comp', :defaults => { :year => 2012, :month => 12, :day => 21 }
plugin.default_auth("*",true)
