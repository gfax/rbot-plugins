#-- vim:sw=2:et
#++
#
# :title: dice plugin for rbot
#
# Author:: Written entirely by me, Lite, because the original author can't spell 'die and dice' correctly.
# Description:: Rolls rpg style dice
# Copyright:: GFAX
# License:: GPL
# Date:: 2012-04-06
#
# Changelog
# 2012-04-06 - fixed typos and syntax errors

class DiceDisplay
  attr_reader :total, :view, :dice
  def initialize(dice, view, total)
    @total = total
    @dice = dice
    @view = view
  end

  def get_view()
    return "\(" + view + "\) "
  end
end

class DicePlugin < Plugin
  Config.register Config::IntegerValue.new('dice.max_dice',
      :default => 100, :validate => Proc.new{|v| v > 0},
      :desc => "Maximum number of dice to throw.")

  Config.register Config::IntegerValue.new('dice.max_sides',
      :default => 100, :validate => Proc.new{|v| v > 0},
      :desc => "Maximum number of sides per die.")

  def help(plugin, topic="")
    plugin + " <dice> (where <dice> can be something like: d6 or 2d6 or 2d6+4 or 2d6+1d20 or 2d6+1d5+4d7-3d4-6)"
  end

  def rolldice(d)
    dice = d.split(/d/)
    repr = []
    r = 0
    unless dice[0] =~ /^\d+/
      dice[0] = 1
    end
    for i in 0...dice[0].to_i
      tmp = rand(dice[1].to_i) + 1
      repr << tmp.to_s
      r = r + tmp
    end
    return DiceDisplay.new(d, repr.join(", "), r)
  end

  def iddice(d)
    dice = d
    porm = d.slice!(0,1)
    if d =~ /d/
      rolled = rolldice(d)
      d = rolled.view
      r = rolled.total
    else
      r = d
    end

    if porm == "-"
      r = 0 - r.to_i
    end

    viewer = DiceDisplay.new(porm + dice, d.to_s, r)
    return viewer
  end

  def privmsg(m)
    # Extract the actual dice request from the message
    # parameters, splitting it into dice and modifiers
    a = m.params.gsub(/\s+/,'').scan(/^\d*d\d+|[+-]\d*d\d+|[+-]\d+/)
    # Check number of total dice and sides per dice
    no = 0
    a.each { |dice|
      dc, ds = dice.split(/d/)
      # check sides
      if ds.to_i > @bot.config['dice.max_sides']
       m.reply "I don't have any dice with more than %u sides" % @bot.config['dice.max_sides'], :nick => true
       return
      end
      # We use .max with 1 so that specs such as d6 count as 1 and not as 0
      no += [dc.to_i, 1].max
    }
    if no > @bot.config['dice.max_dice']
      m.reply "No more than %u dice" % @bot.config['dice.max_dice'], :nick => true
      return
    end

    # Roll the dice with the extracted request
    rolled = rolldice(a[0])
    r = rolled.total
    t = rolled.get_view()

    # Deal with all the remaining parts of the given dice request
    for i in 1...a.length
      tmp = iddice(a[i])
      r = r + tmp.total.to_i
      t = t + tmp.get_view
    end
    t.chop!
    m.reply(r.to_s + " " + t, :nick => true)
  end
end
plugin = DicePlugin.new
plugin.register("dice")
plugin.register("roll")
plugin.register("r")
plugin.register("d")
