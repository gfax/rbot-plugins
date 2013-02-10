# coding: UTF-8
#
# :title: Go Fish
#
# Author:: Lite <degradinglight@gmail.com>
# Copyright:: (C) 2012 gfax.ch
# License:: GPL
# Version:: 2013-02-09
#

class GoFish

  class Card

    COLORS = %w(black red red black)
    RANKS = %w(2 3 4 5 6 7 8 9 10 J Q K A)
    SUITS = %w(clubs diamonds hearts spades)

    attr_accessor :color, :rank, :suit, :shand

    def initialize(id)
      @color = COLORS[id % COLORS.length]
      @rank = RANKS[id % RANKS.length]
      @suit = SUITS[id % SUITS.length]
      @shand = @rank.to_s.downcase + @suit[0] # shorthand, ie. '5d'
    end

    def colorize(color=@suit)
      case color
      when 'diamonds', 'hearts', 'red'
        Irc.color(:red,:white)
      when 'clubs', 'spades', 'black'
        Irc.color(:black,:white)
      end
    end

    def to_s
      symbol = case @suit
        when 'clubs' then '♣'
        when 'diamonds' then '♦'
        when 'hearts' then '♥'
        when 'spades' then '♠'
        end
      Bold + colorize + " #{@rank} " + symbol + " " + NormalText
    end

  end


  class Player

    attr_accessor :cards, :user, :portfolio, :score

    def initialize(user)
      @user = user
      @cards = []
      @portfolio = []
      @score = 0
    end

    def add_card(request)
      @cards << request
    end

    # Feed an array of 2 or 4 cards.
    def cards_match?(request)
      tc = []
      request.each do |e|
        a = has_card?(e)
        tc << a[0]
      end
      if tc.length == 2
        if tc[0].rank == tc[1].rank
          return true if tc[0].color == tc[1].color
        end
      else
        if tc[0].rank == tc[1].rank and tc[0].rank == tc[2].rank
          return true if tc[0].rank == tc[3].rank
        end
      end
      return false
    end

    # Convert array of cards to points.
    def collect_cards(request)
      #raise unless request === Array
      request.each do |c|
        @cards.delete(c)
      end
      if request.length < 4
        @score += request.length
      else
        @score += request.length + 2
      end
    end

    # Don't feed this one arrays.
    def delete_card(request)
      @cards.delete(request)
    end

    # or this one.
    def has_card?(request)
      #raise if request === Array
      has = []
      @cards.each do |c|
        if c.shand == request or c.shand == request.reverse
          has << c
        end
      end
      if has.empty?
        return false
      else
        return has
      end
    end

    def has_rank?(request)
      has = []
      @cards.each do |c|
        if c.rank.to_s.downcase == request.to_s.downcase
          has << c
        end
      end
      if has.empty?
        return false
      else
        return has
      end
    end

    def sort_cards
      # .to_s => sorts by color then rank
      a = @cards.sort {|x,y| x.to_s <=> y.to_s }
      @cards = a.reverse
    end

    def sort_portfolio
      # .rank => sorts by rank
      a = @portfolio.sort {|x,y| x.rank <=> y.rank }
      @portfolio = a.reverse
    end

    def to_s
      Bold + @user.to_s + Bold
    end

  end


  attr_reader :deck, :drawn, :dropouts, :channel, :registry, :manager, :players, :turn

  def initialize(plugin, channel, registry, manager)
    @channel = channel
    @plugin = plugin
    @bot = plugin.bot
    @registry = registry
    @players = []   # players currently in game
    @dropouts = []  # users that aren't allowed to rejoin
    @deck = nil     # card stock
    @turn = nil     # player number
    create_deck
    @manager = manager
    add_player(manager)
  end

  def say(msg, opts={})
    @bot.say channel, msg, opts
  end

  def notify(player, msg, opts={})
    @bot.notice player.user, msg, opts
  end

  def create_deck(copies=1)
    deck_size = Card::RANKS.length * Card::SUITS.length * copies - 1
    # Create an array of numbers and initialize a card for each number.
    @deck = (0..deck_size).to_a.shuffle.collect { |id| Card.new(id) }
  end

  def add_player(user)
    if p = get_player(user)
      say "You're already in the game, #{p}."
      return
    end
    @dropouts.each do |dp|
      if dp.user == user
        say "You dropped from the game, #{dp}. You can't get back in."
        return
      end
    end
    p = Player.new(user)
    @players << p
    if user == manager
      say "#{p} starts a game of Go Fish. Type 'jo' to join."
    else
      say "#{p} joins Go Fish."
    end
    deal(p, 7)
    if @players.length == 2
      countdown = @bot.config['gofish.countdown']
      @bot.timer.add_once(countdown) { start_game }
      say "Game will start in #{Bold}#{countdown}#{Bold} seconds."
    end
  end

  def drop_player(player)
    increment_turn if player == @players[@turn]
    @players.delete(player)
    @dropouts << player
    say "#{player} has been removed from the game."
    end_game if @players.length == 1
  end

  def get_player(user)
    case user
    when User
      @players.each do |p|
        return p if p.user == user
      end
    when String
      @players.each do |p|
        return p if p.user.irc_downcase == user.irc_downcase(channel.casemap)
      end
    else
      get_player(user.to_s)
    end
    return nil
  end

  def has_turn?(src)
    return false if @turn.nil?
    return true if src == @players[@turn].user
    return false
  end

  def start_game
    # Pick a random player to start with.
    @turn = rand(@players.length)
    announce_turn
  end

  def show_cards(player)
    notify player, player.cards.join(' ')
  end

  def show_score(player=nil)
    unless player.nil?
      sep = if player.score == 0 then "" else " -- " end
      say "#{player.user}: #{player.score}#{sep}#{player.portfolio.join(' ')}"
      return
    end
    @players.each do |p|
      sep = if p.score == 0 then "" else " -- " end
      say "#{p}: #{p.score}#{sep}#{p.portfolio.join(' ')}"
    end
    say "Cards left: #{@deck.size}"
  end

  def deal(player, n=1)
    cards = @deck.pop(n)
    unless @turn.nil?
      notify player, "#{Bold}You drew:#{Bold} #{cards.join(' ')}"
    end
    player.cards |= cards
    player.sort_cards
  end

  def get_cards(str)
    request = str.split(' ')
    request.delete_at(0) # => [ "2", "jack" ]
    player = @players[@turn]
    if @players.length == 2
      if @turn == 1
        opponent = @players[0]
      else
        opponent = @players[1]
      end
    else
      if request[1].empty?
        say "Which player do you want to grab a card from?"
        return
      end
      opponent = get_player(request[1])
    end
    unless request[0] =~ /[1-9ajkq]|10/
      say "Tell me which rank you want."
      return
    end
    unless player.has_rank?(request[0])
      say "Hey now, stick to your ranks."
      return
    end
    if player == opponent
      say "You can't give cards to yourself!"
      return
    end
    if opponent.nil?
      say "There is no player '#{request[1]}'."
      return
    end
    result = opponent.has_rank?(request[0])
    unless result
      say "#{opponent.user} has no #{request[0]}'s, Go Fish!"
      deal(player, 1)
      increment_turn
      return
    end
    say "#{player} grabs #{result.join(' and ')} from #{opponent.user}."
    result.each do |c|
      opponent.delete_card(c)
      player.add_card(c)
    end
    player.sort_cards
    announce_turn
  end

  def match_cards(str)
    cards = str.split(' ') # 'm 2d 2h' => [ "m", "2d", "2h" ]
    cards.delete_at(0)
    player = @players[@turn]
    unless cards.length == 2 or cards.length == 4
      say "Specify either 2 or 4 cards."
      return
    end
    cards.each do |c|
      unless player.has_card?(c)
        say "You don't have those cards."
        return
      end
    end
    # [ "2c", "2c" ]
    unless cards.uniq.length == cards.length
      say "You can't match a card with itself."
      return
    end
    # [ "2c", "c2" ]
    cards.each do |c|
      cards.each do |cc|
        if cc == c.reverse
          say "You can't match a card with itself."
          return
        end
      end
    end
    unless player.cards_match?(cards)
      if @players.length == 2
        say "These cards aren't the same rank and color."
      else
        say "These cards aren't the same rank."
      end
      return
    end
    results = []
    # This will take shorthand strings and
    # produce real card objects from them.
    cards.each do |c|
      # has_card returns arrays, so pipe the results into the
      # array instead of concatenating one array into another.
      results |= player.has_card?(c)
    end
    say "#{player.to_s} adds #{results.join(' and ')} to his collection."
    player.collect_cards(results)
    player.portfolio << results.first
    player.sort_portfolio
    show_score(player)
    show_cards(player)
    @players.each do |p|
      if p.cards.empty?
        end_game
        return
      end
    end
  end

  def announce_turn
    if @deck.empty?
      end_game
      return
    end
    player = @players[@turn]
    show_cards(@players[@turn])
    say "It's #{player}'s turn to get a card."
  end

  def increment_turn
    if @turn >= @players.length - 1
      @turn = 0
    else
      @turn += 1
    end
    announce_turn
  end

  def end_game
    score, winner, wstring = -1, [], []
    @players.each do |p|
      if p.score > score
        score = p.score
        winner, wstring = [], []
        winner << p.user
        wstring << p.to_s
      elsif p.score == score
        winner << p.user
        wstring << p.to_s
      end
    end
    @players.each do |p|
      if winner.include? p.user
        update_user_stats(p, 1)
      else
        update_user_stats(p, 0)
      end
    end
    cumulative_score = 0
    @players.each do |p|
      cumulative_score += p.score
    end
    update_chan_stats(cumulative_score)
    if wstring.length == 1
      say "#{wstring.join} wins!"
    else
      say "#{wstring.join(' and ')} tie!"
    end
    show_score
    @plugin.remove_game(channel)
  end

  def update_chan_stats(score)
    if @registry.has_key? channel.name
      @registry[channel.name] = [ @registry[channel.name][0] + 1,
                                  @registry[channel.name][1] + score,
                                  @registry[channel.name][2]
                                ]
    else
      player_hash = {}
      @registry[channel.name] = [ 1, score, player_hash ]
    end
  end

  def update_user_stats(player, win)
    c = channel.name
    nick = player.user.to_s
    p = player.user.downcase
    # Player's channel score:
    if @registry.has_key? c
      player_hash = @registry[c][2]
      if player_hash.has_key? p
        player_hash[p] = { :nick => nick,
                           :wins => player_hash[p][:wins] + win,
                           :games => player_hash[p][:games] + 1,
                           :score => player_hash[p][:score] + player.score
                         }
      else
        player_hash[p] = { :nick => nick,
                           :wins => win,
                           :games => 1,
                           :score => player.score
                         }
      end
      @registry[c] = [ @registry[c][0], @registry[c][1], player_hash ]
    else
      player_hash = {}
      player_hash[p] = { :nick => nick,
                         :wins => win,
                         :games => 1,
                         :score => player.score
                       }
      @registry[c] = [ 0, 0, player_hash ]
    end
    # Player's network-wide score:
    if @registry.has_key? p
      @registry[p] = { :nick => nick,
                       :wins => @registry[p][:wins] + win,
                       :games => @registry[p][:games] + 1,
                       :score => @registry[p][:score] + player.score
                     }
    else
      @registry[p] = player_hash[p]
    end
  end

end


class GoFishPlugin < Plugin

  attr :games

  def initialize
    super
    @games = {}
  end

  def help(plugin, topic='')
    p = @bot.config['core.address_prefix'].first
    case topic
    when /commands?/
      "#{Bold}jo#{Bold} to join in. #{Bold}drop#{Bold} to drop from " +
      "the game. #{Bold}m KD KH KC KS#{Bold} to match 4 cards ('ks' " +
      "and 'sk' are interchangable). #{Bold}g a frank#{Bold} to get " +
      "Aces from your opponent Frank. You only need to specify " +
      "an opponent name if there are more than 2 players."
    when /objectives?/
      "Welcome to the fast-paced, dangerous life of Go Fish! Collect " +
      "matching pairs of any rank (8's, Kings, Aces...) by asking your " +
      "opponents if they have the card you need. If they don't, then Go Fish!"
    when /rules?/
      "Pair up cards with matching rank and color, or match a full " +
      "set of cards with the same rank, (ie. 4 Aces). Pairs are " +
      "worth 2 points and full sets are worth 6 points."
    when /stat(s?|istics?)/
      "#{p}#{plugin} stats [user|chan] to see player or channel stats. " +
      "#{p}#{plugin} stats <chan> <user> a player's stats on that channel. " +
      "#{p}#{plugin} top also shows the current channel's stats."
    else
      "#{Bold}Go Fish#{Bold} help topics: commands, objective, rules, stats"
    end
  end

  Config.register Config::IntegerValue.new('gofish.countdown',
    :default => 10, :validate => Proc.new{|v| v > 2},
    :desc => "Number of seconds before starting a Go Fish game.")

  def message(m)
    return unless @games.key?(m.channel)
    return unless m.plugin
    g = @games[m.channel]
    msg = m.message.downcase
    p = g.get_player(m.source.nick)
    case msg
    when 'jo'
      #return if m.params
      g.add_player(m.source)
    when /^g\b/
      return if p.nil?
      if g.has_turn?(m.source)
        g.get_cards(msg)
      else
        m.reply "Wait your turn, #{m.source.nick}."
      end
    when /^m\b/
      return if p.nil?
      if g.has_turn?(m.source)
        g.match_cards(msg)
      else
        m.reply "Wait your turn, #{m.source.nick}."
      end
    when /^ca?\b/
      if p.nil?
        retort =
          [ "Stop trying to confuse me, #{m.source.nick}!",
            "Sorry, #{m.source.nick}, this is between me and the guys."
          ].sample
        m.reply retort
      end
      m.notify p.cards.join(' ')
    when /^drop/
      return if p.nil?
      unless g.turn.nil?
        g.drop_player(p)
      end
    when /^(sc?|score)\b/
      g.show_score unless g.turn.nil?
    when /^tu\b/
      g.announce_turn unless g.turn.nil?
    end
  end

  def create_game(m, plugin)
    if @games.key?(m.channel)
      user = @games[m.channel].manager
      if m.source == user
        m.reply "...you already started a Go Fish game on this channel."
        return
      else
        m.reply "#{user} already started a Go Fish game on this channel."
        return
      end
    end
    @games[m.channel] = GoFish.new(self, m.channel, self.registry, m.source)
  end

  # Called from within the game.
  def remove_game(channel)
    @games.delete(channel)
  end

  def stop_game(m, plugin)
    @games.delete(m.channel)
    m.okay
  end

  def show_stats(m, params)
    if params[:x].nil?
      x = m.source.nick
    elsif params[:x] == false
      x = m.channel.name.to_s
    else
      x = params[:x].to_s
    end
    xd = x.downcase
    unless @registry.has_key? xd
      if x =~ /^#/
        m.reply "No one has played Go Fish in #{x}."
      elsif x == m.source.nick
        m.reply "You haven't played Go Fish!"
      else
        m.reply "#{x} hasn't played Go Fish."
      end
      return
    end
    if params[:y].nil?
      if x =~ /^#/
        m.reply "#{Bold}#{x}#{Bold} -- " +
                "(games: #{@registry[xd][0]}, " +
                "total score: #{@registry[xd][1]})"
        # Make an array of the channel's top players.
        a = @registry[xd][2].dup
        a = a.to_a.each { |e| e.slice!(0) }
        a.flatten!
        a.sort! { |x,y| y[:score] <=> x[:score] }
        top_players = a.pop(5)
        n = 1
        top_players.each do |k|
          m.reply "#{Bold}#{n}. #{k[:nick]}#{Bold} - #{k[:score]}pts. " +
                  "(#{k[:wins]}/#{k[:games]} games won)"
          n += 1
          end
        return
      else
        m.reply "#{Bold}#{@registry[xd][:nick]}#{Bold} -- " +
                "Wins: #{@registry[xd][:wins]}, " +
                "games: #{@registry[xd][:games]}, " +
                "score: #{@registry[xd][:score]}"
        return
      end
    end
    y = params[:y].to_s.downcase
    unless @registry[x][2].has_key? y
      "They haven't played a game in this channel, #{m.source.nick}"
      return
    end
    m.reply "#{Bold}#{@registry[x][2][y][:nick]}#{Bold} (in #{x}) -- " +
            "Wins: #{@registry[x][2][y][:wins]}, " +
            "games: #{@registry[x][2][y][:games]}, " +
            "score: #{@registry[x][2][y][:score]}"
  end

end


plugin = GoFishPlugin.new

[ 'fish', 'gofish' ].each do |scope|
  plugin.map "#{scope} cancel",
    :private => false, :action => :stop_game
  plugin.map "#{scope} end",
    :private => false, :action => :stop_game
  plugin.map "#{scope} stat[s] [:x [:y]]",
    :action => :show_stats
  plugin.map "#{scope} stop",
    :private => false, :action => :stop_game
  plugin.map "#{scope} top",
    :action => :show_stats, :defaults => { :x => false }
  plugin.map "#{scope}",
    :private => false, :action => :create_game
end
