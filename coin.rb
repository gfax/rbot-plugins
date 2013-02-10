# :title: Coin Toss
#
# Author:: jazzyfox <jazzyfox@gmail.com>
# Author:: Lite <degradinglight@gmail.com>
# URL:: https://github.com/gfax/rbot-plugins.git
# Version:: 2013-02-09
#


class CoinPlugin < Plugin

  def help(plugin, topic='')
    p = @bot.config['core.address_prefix'].first
    return "#{p}#{plugin} => flip a coin, " +
           "#{p}#{plugin} stats => show your coin flipping stats"
  end

  def initialize
    @coin = ['heads', 'tails']
    super
  end

  def flip_coin(m, params)
    num = params[:number].to_i
    m.reply "I can only flip positive numbers of coins." unless num > 0
    m.reply "Sorry, I've only got 20 coins in my pocket." unless num <= 20
    return unless num > 0 && num <= 20
    playerdata = get_data(m.sourcenick) || Array.new(2,0)
    result = []
    1.upto(num) do |i|
      flip = rand(2)
      playerdata[flip] += 1
      result << @coin[flip]
    end
    m.reply result.join(', ')
    @registry[m.sourcenick.downcase] = playerdata
  end

  def coin_stats(m, params)
    data = params[:nick] ? get_data(params[:nick]) : get_data(m.sourcenick)
    if data
      total = data.inject {|sum, i| sum + i}
      heads, tails = data
      hp, tp = data.map {|i| sprintf("%.2f", (i.to_f / total) * 100)}
      m.reply "#{heads} heads (#{hp}%) and #{tails} tails (#{tp}%)"
    elsif params[:nick]
      m.reply "Sorry, #{params[:nick]} hasn't flipped any coins."
    else
      m.reply "Sorry, you haven't flipped any coins."
    end
  end

  private

  def get_data(name)
    @registry[name.downcase] if @registry.has_key?(name.downcase)
  end

end

plugin = CoinPlugin.new

[ 'coin', 'cointoss' ].each do |scope|
  plugin.map "#{scope} stats [:nick]",
    :action => 'coin_stats'
  plugin.map "#{scope} :number", 
    :action => 'flip_coin', :defaults => { :number => 1 }
end
