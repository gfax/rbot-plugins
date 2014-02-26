#
# :title: uptime
#
# Author:: gfax
# Copyright:: (C) 2014 gfax
# License:: GPL
# Version:: 2014-02-25

class UptimePlugin < Plugin

  def help(plugin, topic)
    'Returns date since last system reboot.'
  end

  def last_reboot(m, plugin)
    captures = (`uptime`.match /up (?:(?:(\d+) days,)?\s+(\d+):(\d+)|(\d+) min)/).captures
    elapsed_seconds = captures.zip([86440, 3600, 60, 60]).inject(0) do |total, (x,y)|
      total + (x.nil? ? 0 : x.to_i * y)
    end
    m.reply "Last reboot was on #{Time.now - elapsed_seconds}."
  end

end


plugin = UptimePlugin.new
plugin.map 'uptime', :action => 'last_reboot'
