#-- vim:sw=2:et
#++
#
# :title: Yahoo! Weather
#
# Author:: Lite
# Copyright:: (C) 2012 Lite
# License:: GPL
# Version:: 2013-01-19

class YWeatherPlugin < Plugin

  URL = "http://weather.yahooapis.com/forecastrss"

  def help(plugin, topic="")
    p = @bot.config['core.address_prefix'].first
    case topic.downcase
    when 'set'
      "Use \"#{p}w set <zipcode|woeid>\" to set " +
      "your default zipcode or Yahoo! woeid."
    else
      "#{p}w <zip|woeid> for local weather -- #{p}fc <zip|woeid> " +
      "for two-day forecast. (see also #{p}help #{plugin} set)"
    end
  end

  def weather(m, params)
    location = params[:id]
    if location.nil? or location.empty?
      if @registry.has_key? m.sourcenick.downcase
        location = @registry[ m.sourcenick.downcase ]
      else
        m.reply "Invalid zip/id."
        return
      end
    end 
    feed = if location.length == 5
             @bot.httputil.get URL + "?p=#{location}"
           else
             @bot.httputil.get URL + "?w=#{location}&u=c"
           end
    if feed.nil?
      m.reply "Yahoo! Weather unavailable."
      return
    end
    xml = REXML::Document.new feed
    degrees = xml.elements['//yweather:units'].attributes['temperature']
    condition = xml.elements['//yweather:condition'].attributes['text']
    city = xml.elements['//yweather:location'].attributes['city']
    humidity = xml.elements['//yweather:atmosphere'].attributes['humidity']
    region = xml.elements['//yweather:location'].attributes['region']
    temp = xml.elements['//yweather:condition'].attributes['temp']
    if params[:forecast]
      xml.elements.each("//yweather:forecast") do |e|
        m.reply "#{Bold}#{e.attributes['day']}:#{Bold} " +
                e.attributes['low'] + '/' + e.attributes['high'] + degrees +
                ', ' + e.attributes['text']
      end
    else
      m.reply "#{city}, #{region} - #{temp}#{degrees}/#{humidity}\% humidity, #{condition}"
    end
  end

  def set_user(m, params)
    location = params[:id].to_s
    @registry[ m.sourcenick.downcase ] = location
    m.okay
  end

end

p = YWeatherPlugin.new
p.map "w [:id]", :action => "weather", :defaults => { :forecast => false }
p.map "weather [:id]", :action => "weather", :defaults => { :forecast => false }
p.map "wz [:id]", :action => "weather", :defaults => { :forecast => false }
p.map "fc [:id]", :action => "weather", :defaults => { :forecast => true }
p.map "forecast [:id]", :action => "weather", :defaults => { :forecast => true }
p.map "w set [zip[code]] [:id]", :action => "set_user"
p.map "wz set [zip[code]] [:id]", :action => "set_user"
