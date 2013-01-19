#-- vim:sw=2:et
#++
#
# :title: Url plugin
# :version: 2012-06-08

define_structure :Url, :channel, :nick, :time, :url, :info

class UrlPlugin < Plugin
  OUR_UNSAFE = Regexp.new("[^#{URI::PATTERN::UNRESERVED}#{URI::PATTERN::RESERVED}%# ]", false, 'N')

  Config.register Config::IntegerValue.new('url.display_link_info',
    :default => 2,
    :desc => "Get the title of links pasted to the channel and display it " +
             "(also tells if the link is broken or the site is down). Do " +
             "it for at most this many links per line (set to 0 to disable)")
  Config.register Config::BooleanValue.new('url.titles_only',
    :default => true,
    :desc => "Only show info for links that have <title> tags (in " +
             "other words, don't display info for jpegs, mpegs, etc.)")
  Config.register Config::BooleanValue.new('url.first_par',
    :default => false,
    :desc => "Also try to get the first paragraph of a web page")
  Config.register Config::BooleanValue.new('url.info_on_list',
    :default => false,
    :desc => "Show link info when listing/searching for urls")
  Config.register Config::ArrayValue.new('url.whitelist',
    :default => ['youtube\.com','youtu\.be', 'vimeo\.com'],
    :on_change => Proc.new { |bot, v| bot.plugins['url'].reset_whitelist },
    :desc => "A list of regular expressions matching hosts for " +
             "which it is okay for information to be provided")
  Config.register Config::ArrayValue.new('url.only_on_channels',
    :desc => "Show link info only on these channels",
    :default => [])
  Config.register Config::ArrayValue.new('url.ignore',
    :desc => "Don't show link info for urls from users represented as hostmasks " +
             "on this list. Useful for ignoring other bots, for example.",
    :default => [])

  def initialize
    super
    unless @bot.config['url.display_link_info'].kind_of?(Integer)
      @bot.config.items[:'url.display_link_info'].set_string(@bot.config['url.display_link_info'].to_s)
    end
    reset_whitelist
    self.filter_group = :htmlinfo
    load_filters
  end

  def reset_whitelist
    @whitelist = Regexp.new(@bot.config['url.whitelist'].join('|'), true)
    debug "whitelist regexp set to #{@whitelist}"
  end

  def help(plugin, topic="")
    "url info <url> => display link info for <url> (set url.display_link_info" +
    "> 0 if you want the bot to do it automatically when someone writes an url)"
  end

  def get_title_from_html(pagedata)
    return pagedata.ircify_html_title
  end

  def get_title_for_url(uri_str, opts = {})

    url = uri_str.kind_of?(URI) ? uri_str : URI.parse(uri_str)
    return if url.scheme !~ /https?/

    # also check the ip, the canonical name and the aliases
    begin
      checks = TCPSocket.gethostbyname(url.host)
      checks.delete_at(-2)
    rescue => e
#      return "Unable to retrieve info for #{url.host}: #{e.message}"
      return
    end

    checks << url.host
    checks.flatten!

    if checks.grep(@whitelist).empty?
      return ( opts[:always_reply] ? "Sorry, info retrieval for #{url.host} (#{checks.first}) is disabled" : false )
    end

    logopts = opts.dup

    title = nil
    extra = []

    begin
      debug "+ getting info for #{url.request_uri}"
      info = @bot.filter(:htmlinfo, url)
      debug info
      logopts[:htmlinfo] = info
      resp = info[:headers]

      logopts[:title] = title = info[:title]

      if info[:content]
        logopts[:extra] = info[:content]
        extra << "#{Bold}text#{Bold}: #{info[:content]}" if @bot.config['url.first_par']
      else
        logopts[:extra] = String.new
        logopts[:extra] << "Content Type: #{resp['content-type']}"
        extra << "#{Bold}type#{Bold}: #{resp['content-type']}" unless title
        if enc = resp['content-encoding']
          logopts[:extra] << ", encoding: #{enc}"
          extra << "#{Bold}encoding#{Bold}: #{enc}" if @bot.config['url.first_par'] or not title
        end

        size = resp['content-length'].first.gsub(/(\d)(?=\d{3}+(?:\.|$))(\d{3}\..*)?/,'\1,\2') rescue nil
        if size
          logopts[:extra] << ", size: #{size} bytes"
          extra << "#{Bold}size#{Bold}: #{size} bytes" if @bot.config['url.first_par'] or not title
        end
      end
    rescue Exception => e
      case e
      when UrlLinkError
        raise e
      else
        error e
        raise "connecting to site/processing information (#{e.message})"
      end
    end

    call_event(:url_added, url.to_s, logopts)
    if title
      extra.unshift("#{title}")
    end
    return extra.join(", ") if title or not @bot.config['url.titles_only']
  end

  def handle_urls(m, params={})
    opts = {
      :display_info => @bot.config['url.display_link_info'],
      :channels => @bot.config['url.only_on_channels'],
      :ignore => @bot.config['url.ignore']
    }.merge params
    urls = opts[:urls]
    display_info= opts[:display_info]
    channels = opts[:channels]
    ignore = opts[:ignore]

    unless channels.empty?
      return unless channels.map { |c| c.downcase }.include?(m.channel.downcase)
    end

    ignore.each { |u| return if m.source.matches?(u) }

    return if urls.empty?
    debug "found urls #{urls.inspect}"
    list = m.public? ? @registry[m.target] : nil
    debug "display link info: #{display_info}"
    urls_displayed = 0
    urls.each do |urlstr|
      debug "working on #{urlstr}"
      next unless urlstr =~ /^https?:\/\/./
      if @bot.config['url.auto_shorten'] == true and
         urlstr.length >= @bot.config['url.auto_shorten_min_length']
        m.reply(bot.plugins['shortenurls'].shorten(nil, {:url=>urlstr, :called=>true}))
        next
      end
      title = nil
      debug "Getting title for #{urlstr}..."
      reply = nil
      begin
        title = get_title_for_url(urlstr,
                                  :always_reply => m.address?,
                                  :nick => m.source.nick,
                                  :channel => m.channel,
                                  :ircline => m.message)
        debug "Title #{title ? '' : 'not '} found"
        reply = "\(#{title}\)" if title
      rescue => e
        debug e
        # we might get a 404 because of trailing punctuation, so we try again
        # with the last character stripped. this might generate invalid URIs
        # (e.g. because "some.url" gets chopped to some.url%2, so catch that too
        if e.message =~ /\(404 - Not Found\)/i or e.kind_of?(URI::InvalidURIError)
          # chop off last non-word character from the unescaped version of
          # the URL, and retry if we still have enough string to look like a
          # minimal URL
          unescaped = URI.unescape(urlstr)
          debug "Unescaped: #{unescaped}"
          if unescaped.sub!(/\W$/,'') and unescaped =~ /^https?:\/\/./
            urlstr.replace URI.escape(unescaped, OUR_UNSAFE)
            retry
          else
            debug "Not retrying #{unescaped}"
          end
        end
        reply = "Error #{e.message}"
      end
      if display_info > urls_displayed
        if reply
          m.reply reply, :overlong => :truncate, :to => :public,
            :nick => (m.address? ? :auto : false)
          urls_displayed += 1
        end
      end

      next unless list
      # check to see if this url is already listed
      next if list.find {|u| u.url == urlstr }
      url = Url.new(m.target, m.sourcenick, Time.new, urlstr, title)
      debug "#{list.length} urls so far"
      list.pop if list.length > @bot.config['url.max_urls']
      debug "storing url #{url.url}"
      list.unshift url
      debug "#{list.length} urls now"
    end
  end

  def info(m, params)
    escaped = URI.escape(params[:urls].to_s, OUR_UNSAFE)
    urls = URI.extract(escaped)
    Thread.new do
      handle_urls(m,
                  :urls => urls,
                  :display_info => params[:urls].length,
                  :channels => [])
    end
  end

  def message(m)
    return if m.address?
    escaped = URI.escape(m.message, OUR_UNSAFE)
    urls = URI.extract(escaped, ['http', 'https'])
    return if urls.empty?
    Thread.new { handle_urls(m, :urls => urls) }
  end


end

plugin = UrlPlugin.new
plugin.map 'urls info *urls', :action => 'info'
plugin.map 'url info *urls', :action => 'info'
