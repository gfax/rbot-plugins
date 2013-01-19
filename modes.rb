class ModesPlugin < Plugin

  def help(plugin, topic="")
    return "'op [<user>] [<channel>]' => grant user> (if ommitted yourself) ops in <channel> (or in the current channel if no channel is specified). Use deop instead of op to remove the privilege."
  end

  def op(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "+o")
  end

  def opme(m, params)
    params[:user] = m.sourcenick
    op(m, params)
  end

  def deop(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "-o")
  end

  def deopme(m, params)
    params[:user] = m.sourcenick
    deop(m, params)
  end

  def hop(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "+h")
  end

  def hopme(m, params)
    params[:user] = m.sourcenick
    hop(m, params)
  end

  def dehop(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "-h")
  end

  def dehopme(m, params)
    params[:user] = m.sourcenick
    dehop(m, params)
  end

  def v(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "+v")
  end

  def voice(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "+v")
  end

  def voiceme(m, params)
    params[:user] = m.sourcenick
    voice(m, params)
  end

  def devoice(m, params)
    channel = params[:channel]
    user = params[:user]
    do_mode(m, channel, user, "-v")
  end

  def devoiceme(m, params)
    params[:user] = m.sourcenick
    devoice(m, params)
  end

  def do_mode(m, channel, user, mode)
    unless channel
      if m.private?
        target = user.nil? ? "you" : user
        m.reply "You should tell me where you want me to #{mode} #{target}."
        return
      else
        channel = m.channel
      end
    else
      channel = m.server.channel(channel)

      unless channel.has_user?(@bot.nick)
        m.reply "I am not in that channel"
	return
      end
    end

    unless user
      user = m.sourcenick
    end
    return if m.server.get_user(user).is_op?(channel)
    return unless m.source.is_voice?(channel) or m.source.is_op?(channel)
    m.okay unless channel == m.channel.to_s
    @bot.mode(channel, mode, user)
  end
end

plugin = ModesPlugin.new
plugin.map'op [:user] [:channel]', :auth_path => 'op'
plugin.map'opme [:channel]', :auth_path => 'op'
plugin.map'deop [:user] [:channel]', :auth_path => 'op'
plugin.map'deopme [:channel]', :auth_path => 'op'
plugin.map'hop [:user] [:channel]', :auth_path => 'hop'
plugin.map'hopme [:channel]', :auth_path => 'hop'
plugin.map'dehop [:user] [:channel]', :auth_path => 'hop'
plugin.map'dehopme [:channel]', :auth_path => 'hop'
plugin.map'v [:user] [:channel]'
plugin.map'voice [:user] [:channel]'
plugin.map'voiceme [:channel]'
plugin.map'devoice [:user] [:channel]'
plugin.map'devoiceme [:channel]'
plugin.default_auth('op', false)
plugin.default_auth('hop', false)
