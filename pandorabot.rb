#-- vim:sw=2:et
#++
#
# Author:: Casey Link <unnamedrambler@gmail.com>
# Copyright:: (C) 2008 Casey Link
# Author:: Jay Thomas <degradinglight@gmail.com>
# Copyright:: (C) 2013 gfax


class PandoraBotPlugin < Plugin

  Config.register Config::ArrayValue.new 'pandorabot.talk_to',
    :desc => 'Talk only to these channels and users.',
    :default => []
  Config.register Config::BooleanValue.new 'pandorabot.enabled',
    :default => false,
    :desc => 'Enable and disable the plugin.'
  Config.register Config::IntegerValue.new 'pandorabot.probability',
    :default => 500, :validate => Proc.new{|v| v > 0},
    :desc => 'Chance of randomly replying.'
  Config.register Config::StringValue.new 'pandorabot.botid',
    #:default => 'a211adf15e36b67b', #God
    :default => 'd7ffebfd7e34502b', # Awol
    :desc => 'The pandorabot.com botid.'

  def initialize
    super
    @custid = nil
    class << @registry
      def store(val)
        val
      end
      def restore(val)
        val
      end
    end
  end

  def help(plugin, topic='')
    "pandorabot plugin: a chatbot that uses bots from pandorabot.com. usage: " +
    "#{plugin} <statement> will send the statement to the bot. " +
    "#{plugin} enable/disable will toggle the bot's responses on or off. " +
    "#{plugin} status to see the status of the bot. To change which bot "
    "is being talked to, edit the pandorabot.botid config value."
  end

  def message(m)
    return unless @bot.config['pandorabot.enabled']
    case rand(@bot.config['pandorabot.probability'])
    when 0 then ask_question(m)
    end
  end

  def ask_question(m, params=nil)
    return unless @bot.config['pandorabot.enabled']
    return unless @bot.config['pandorabot.botid']
    return unless @bot.config['pandorabot.talk_to'].include? m.channel.name
    if params
      question = params[:question] || m.message
    else
      question = m.message
    end
    botid = @bot.config['pandorabot.botid']
    uri = "http://www.pandorabots.com/pandora/talk-xml"
    botid = "botid=#{botid}"
    input = "input=#{CGI.escape(question)}"
    
    body = nil
    if @registry.has_key?( m.sourcenick )
      custid = "custid=#{@registry[ m.sourcenick ]}"
      body = [botid,custid,input].join("&")
    else
      body = [botid,input].join("&")
    end

    response = @bot.httputil.post(uri, body)
    debug response
    if response.class == Net::HTTPOK
      xmlDoc = REXML::Document.new(response.body)
      status = xmlDoc.elements['result'].attributes['status']
      custid = xmlDoc.elements['result'].attributes['custid']
      unless @registry.has_key?( m.sourcenick )
        @registry[ m.sourcenick ] = custid
      end
      case status
      when '0'
        m.reply xmlDoc.elements['result/that'].get_text.value.ircify_html
      else
        m.reply 'Say again?'
      end
    else
      m.reply 'Excuse me?' # the http request failed
    end
  end

  def status(m, params)
    return unless @bot.config['pandorabot.talk_to'].include? m.channel.name
    msg = "My AI is "
    if @bot.config['pandorabot.enabled']
      msg << "enabled. "
    else
      msg << "disabled. "
    end
    msg << "Currently using bot #{@bot.config['pandorabot.botid']}."
    m.reply msg
  end

end    

plugin = PandoraBotPlugin.new
[ 'dark', 'Dark', 'DARK' ].each do |scope|
  plugin.map "#{scope} status",
    :action => "status"
  plugin.map "#{scope} *question",
    :action => "ask_question", :threaded => true
end
