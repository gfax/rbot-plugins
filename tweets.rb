#-- vim:sw=2:et
#++
#
# :title: Tweets
#
# Listens for twitter urls and fetches content of tweets
#
# Author:: Patric Mueller <bhaak@gmx.net>
# Author:: Jay Thomas <degradinglight@gmail.com>
#
# Copyright:: (C) 2010 Patric Mueller
# Copyright:: (C) 2013 Jay Thomas
#
# License:: MIT license

class TweetsPlugin < Plugin

  API_URL = "http://api.twitter.com/1/statuses/show/%{status_number}.xml"

  Config.register Config::BooleanValue.new('tweets.show_timestamps',
    :default => false,
    :desc => "Show timestamps on tweets."
  )

  Config.register Config::BooleanValue.new('tweets.all_channels',
    :default => false,
    :desc => "Retrieve tweets from urls on all " +
             "channels instead of certain channels."
  )
  Config.register Config::ArrayValue.new('tweets.channels',
    :desc => "Show tweet info only on these channels.",
    :default => []
  )

  def get_twitter_content(status_number)
    begin
      tweet = @bot.httputil.get API_URL % { :status_number => status_number }
      xml = REXML::Document.new tweet
      timestamp = if @bot.config['tweets.show_timestamps']
                    "(#{xml.elements['//status/created_at'].text[0..15]}) "
                  else ''
                  end
      user = xml.elements['//user/name'].text
      text = xml.elements['//status/text'].text
      return "#{timestamp}#{Bold}#{user}:#{Bold} #{text}"
    rescue => e
      return e.message
    end
  end

  def listen(m)
    channel = @bot.config['tweets.channels'].map { |c| c.downcase }.include?(m.channel.downcase)
    return unless channel or @bot.config['tweets.all_channels']
    urls = m.message.split.select {|v| v =~ /^(https?:\/\/twitter.com\/.*\/status\/.*)/}
    urls.each do |u|
      ret = get_twitter_content(/status\/(.*)/.match(u)[1])
      m.reply ret if ret
    end
  end

end

plugin = TweetsPlugin.new
