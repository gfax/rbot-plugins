#-- vim:sw=2:et
#++
#
# :title: Autovoice
# Author:: gfax
# Copyright:: (C) 2012 gfax
# License:: GPL
# Version: 2012-05-14

class AutoVoice < Plugin
  Config.register Config::BooleanValue.new('autovoice.on_nick',
    :default => true,
    :desc => "Determines if the bot should auto-voice when someone changes nick " +
             "and the new nick matches a listed netmask")

  Config.register Config::StringValue.new('autovoice.seed_format',
    :default => "*!%{user}@*",
    :desc => "Hostmask format used when seeding channels. Recognized tokens: " +
             "nick, user, host")

  def help(plugin, topic="")
    return "perform autovoice based on hostmask - usage:" +
           "add <hostmask> [channel channel ...], rm <hostmask> [channel], " +
             "If you don't specify which channels, all channels are assumed, " +
           "list - list current voices, " +
           "restore [channel] - voice anybody that would " +
             "have been voiced if they had just joined, " +
           "seed [channel] - Find current voices and make sure they will " +
             "continue to be voiced"
  end

  def join(m)
    return if m.address?
    @registry.each { |mask,channels|
      if m.source.matches?(mask.to_irc_netmask(:server => m.server)) &&
        (channels.empty? || channels.include?(m.channel.to_s))
        @bot.mode(m.channel, "+v", m.source.nick)
        return
      end
    }
  end

  def nick(m)
    return if m.address?
    return unless @bot.config['autovoice.on_nick']
    is_on = m.server.channels.inject(ChannelList.new) { |list, ch|
      list << ch if ch.users.include?(m.source)
      list
    }
    is_on.each { |channel|
      ch = channel.to_s
      @registry.each { |mask,channels|
        if m.source.matches?(mask.to_irc_netmask(:server => m.server)) &&
          (channels.empty? || channels.include?(ch))
          @bot.mode(ch, "+v", m.source.nick)
          return
        end
      }
    }
  end

  def add(m, params)
    if params[:channels].empty? || !@registry.has_key?(params[:mask])
      # if the channels parameter is omitted (meaning all channels), or the
      # hostmask isn't present in the registry, we just (over)write the channels
      # in the registry
      @registry[params[:mask]] = params[:channels].dup
      m.okay
    else
      # otherwise, merge the channels with the ones existing in the registry
      current_channels = @registry[params[:mask]]
      if current_channels.empty?
        m.reply "#{params[:mask]} is already being auto-voiced on all channels"
      else
        # merge the already set channels
        @registry[params[:mask]] = (params[:channels] | current_channels).uniq
        m.okay
      end
    end
  end

  def seed(m, params)
    chan = params[:channel]
    if chan == nil
      if m.public?
        chan = m.channel
      else
        m.reply _("Either specify a channel to seed, or ask in public")
      end
    end

    current_voices = @bot.server.channel(chan).users.select { |u|
        u.is_voice?(chan) and u.nick != @bot.nick
    }

    netmasks = current_voices.map { |u|
      @bot.config['autovoice.seed_format'] % {
        :user => u.user,
        :nick => u.nick,
        :host => u.host
      }
    }.uniq

    to_add = netmasks.select { |mask|
        @registry.key?(mask) == false or @registry[mask].empty? == false
    }

    if to_add.empty?
      m.reply _("Nobody to add")
      return
    end

    results = []
    to_add.each { |mask|
      if @registry.key? mask
        if @registry[mask].include? chan
          next
        else
          current_channels = @registry[mask].dup
          @registry[mask] = ([chan] | current_channels).uniq
          results << _("Added #{mask} in #{chan}")
        end
      else
        @registry[mask] = [chan]
        results << _("Created autovoice entry for #{mask} and added #{chan}")
      end
    }
    m.reply results.join ". "
  end

  def rm(m, params)
    unless @registry.has_key?(params[:mask])
      m.reply @bot.lang.get('dunno')
      return
    end
    if (!params[:channels].empty? && @registry[params[:mask]] != nil)
      params[:channels].each do |c|
        @registry[params[:mask]] = @registry[params[:mask]].reject {|ele| ele =~ /^#{c}$/i}
      end
      if @registry[params[:mask]].empty?
        @registry.delete(params[:mask])
      end
    else
      @registry.delete(params[:mask])
    end
    m.okay
  end

  def list(m, params)
    debug @registry.length
    if(@registry.length > 0)
      @registry.each { |mask,channels|
        m.reply "#{mask} in #{channels.empty? ? 'all channels' : channels.join(', ')}"
      }
    else
      m.reply "No entries"
    end
  end

  def restore(m, params)
    chan = params[:channel]
    if chan == nil
      if m.public?
        chan = m.channel
      else
        m.reply _("Either specify a channel to restore, or ask in public")
      end
    end

    current_non_voices = @bot.server.channel(chan).users.select { |u|
      u.is_voice?(chan) == nil and u.nick != @bot.nick
    }

    @registry.each { |mask,channels|
      if channels.empty? || channels.include?(chan)
        current_non_voices.each { |victim|
          if victim.matches?(mask.to_irc_netmask(:server => m.server))
            @bot.mode(chan, "+v", victim)
          end
        }
      end
    }
  end
end

plugin = AutoVoice.new

plugin.map 'autovoice list', :action => 'list'
plugin.map 'autovoice add :mask [*channels]', :action => 'add'
plugin.map 'autovoice rm :mask [*channels]', :action => 'rm'
plugin.map 'autovoice seed [:channel]', :action => 'seed'
plugin.map 'autovoice restore [:channel]', :action => 'restore'

plugin.default_auth('*',false)
