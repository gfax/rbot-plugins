#-- vim:sw=2:et
#++
#
# :title: Yahoo! Weather
#
# Author:: Lite
# Copyright:: (C) 2012 Lite
# License:: GPL
#

class YWeatherPlugin < Plugin

  def help(plugin, topic="")
    case (topic.intern rescue nil)
    when :set
      "Use \"!w set <zipcode|woeid>\" to save your zipcode or Yahoo! woeid."
      else
      "!w <zip|woeid> for local weather -- !fc <zip|woeid> for two-day forecast. (see also !help #{plugin} set)"
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
  if location.length == 5
    feed = Net::HTTP.get 'weather.yahooapis.com', "/forecastrss?p=#{location}"
    else
    feed = Net::HTTP.get 'weather.yahooapis.com', "/forecastrss?w=#{location}&u=c"
    end
  if feed.nil? or feed.empty?
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
    xml.elements.each("//yweather:forecast") {
      |e| m.reply "#{Bold}" + e.attributes["day"] + ":#{Bold} " + e.attributes["low"] + "/" + e.attributes["high"] + degrees + ", " + e.attributes["text"]
      }
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

plugin = YWeatherPlugin.new
plugin.map "w [:id]", :action => "weather", :defaults => { :forecast => false }
plugin.map "weather [:id]", :action => "weather", :defaults => { :forecast => false }
plugin.map "wz [:id]", :action => "weather", :defaults => { :forecast => false }
plugin.map "fc [:id]", :action => "weather", :defaults => { :forecast => true }
plugin.map "forecast [:id]", :action => "weather", :defaults => { :forecast => true }
plugin.map "w set [:id]", :action => "set_user"
plugin.map "wz set [:id]", :action => "set_user"
plugin.default_auth("*",true)
