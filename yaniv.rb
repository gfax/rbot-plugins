# coding: utf-8
#
# Title:: Love Letter
# Author:: Jay Thomas <degradinglight@gmail.com>
# Copyright:: (C) 2013 gfax
# License:: GPL
# Version:: 2013-08-08
#

class Yaniv

  Title = Bold + 'Yaniv' + Bold

  class Card

    Ranks = %W(2 3 4 5 6 7 8 9 10 J Q K A)
    Suits = [ :clubs, :diamonds, :hearts, :spades ]

    attr_accessor :color, :rank, :suit, :shand
    attr_reader :name, :rank, :suit

    def initialize(id)
      if id.between?(1,52)
        @rank = Ranks[id % Ranks.length]
        @suit = Suits[id % Suits.length]
      else
        @rank = 'J'
        @suit = :joker
      end
    end

    def name
      # shorthand, ie. '5d'
      if suit == :joker
        rank.downcase
      else
        rank.downcase + suit.to_s[0]
      end
    end

    def to_s
      color = case suit
        when :diamonds, :hearts
          Irc.color(:red,:white)
        when :clubs, :spades
          Irc.color(:black,:white)
        when :joker
          Irc.color(:limegreen, :white)
        end
      symbol = case suit
        when :clubs then ' ♣'
        when :diamonds then ' ♦'
        when :hearts then ' ♥'
        when :spades then ' ♠'
        else ''
        end
      Bold + color + ' ' + rank + symbol + ' ' + NormalText
    end

  end


  class Player

    attr_accessor :user, :discarded, :drew, :hand

    def initialize(user)
      @user = user
      @discarded = false
      @drew = false
      @hand = []
    end

    def get_card(card)
      return false if card.nil?
      if card.is_a? String
        hand.each do |e|
          return e if card == e.shorthand or card.reverse == e.shorthand
        end
      end
      return nil
    end

    def sort_cards
      @cards = cards.sort {|x,y| x.suit <=> y.suit }
    end

    def to_s
      Bold + user.to_s + Bold
    end

  end


  attr_reader :channel, :deck, :dropped, :join_timer, :last_discard, 
              :manager, :players, :started, :temp_discard

  def initialize(plugin, channel, user, rounds)
    @bot = plugin.bot
    @channel = channel
    @plugin = plugin
    @registry = plugin.registry
    @deck = []         # card stock
    @dropped = []      # players booted from game
    @join_timer = nil  # timer for countdown
    @last_discard = [] # cards last player discarded
    @manager = nil     # player in control of game
    @players = []      # players currently in game
    @started = nil     # time the game started
    @temp_discard = [] # cards to be discarded after draw
    add_player(user)
  end

  def add_player(user)
    if player = get_player(user)
      say "You're already in the game #{player}."
      return
    end
    player = Player.new(user)
    @players << player
    if manager.nil?
      @manager = player
      say "#{player} creates a game of #{Title}. Type 'j' to join."
    else
      say "#{player} joins #{Title}."
    end
    player.hand << @deck.pop if started
    if @join_timer
      if players.size == 4
        @bot.timer.remove(@join_timer)
        do_round
      else
        @bot.timer.reschedule(@join_timer, 10)
      end
    elsif players.size > 1
      countdown = @bot.config['yaniv.countdown']
      @join_timer = @bot.timer.add_once(countdown) { start_game }
      say "Game will start in #{countdown} seconds."
    end
  end

  def do_discard(player, cards)
    a.map! { |e| player.get_card(e) }
    a.reject! { |e| e.nil? }
    
  end

  def do_draw(player, card)
    a.each do |e|
      e = e.to_i
      next unless e.between?(1,last_discard.size + 1)
      case e
      when 1
        if deck.empty?
          @deck |= @discard
          @discard.clear
          @bot.action channel, "shuffles the deck."
          @deck.shuffle!
        end
        player.hand << @deck.pop
        say "#{player} draws from the deck."
        notify player, "#{Bold}You drew:#{Bold} #{player.cards.last}."
      else
        player.hand << last_discard[e-2]
        say "#{player} draws from the discard."
        notify player, "#{Bold}You drew:#{Bold} #{last_discard[e-2]}"
        @last_discard.delete_at(e-2)
      end
      player.sort_cards
      return true
    end
    a.each do |e| 
      card = get_card(e) if card.zero?
    end
  end

  def do_turn(hold_place=false)
    if hold_place
    else
      @players << @players.shift
    end
    player = players.first
    player.discarded = player.drew = false
    say "It's player's turn."
  end

  def drop_player(dropper, a)
    case a.first
    when nil, 'me' then player = dropper
    else player = get_player(a.first, dropper)
    end
    if player.nil?
      say "#{dropper}, there is no one playing named '#{a.first}'."
      return
    elsif player != dropper and dropper != manager
      say "Only the game manager is allowed to drop others, #{dropper}."
      return
    end
    n = 0
    n += 1 until players[n] == player
    n = next_turn(n)
    if player == manager and players.size > 2
      unless players[n].user == @bot.nick
        @manager = players[n]
      else
        @manager = players[next_turn(n)]
      end
      say "#{manager} is now game manager."
    end
    say "#{player} has been removed from the game."
    @dropouts << player
    @players.delete(player)
    # If the manager drops the only other player, end the game.
    if players.size < 2
      say "#{player} has been removed from the game. #{Title} stopped."
      @plugin.remove_game(channel)
    else
      do_turn(true) if player == players.first
    end
  end

  def elapsed_time
    return Utils.secs_to_string(Time.now-started)
  end

  def end_game
    players.first.discarded = true
    players.first.drew = true
    # Time spent playing the game.
    @started = Time.now.to_i - started.to_i
    a = []
    winners = players.sort { |x, y| x.score <=> y.score }
    winners.each { |p| a << "#{p} - #{p.score}"  }
    say 'The end. ' + a.join(', ')
    winners.reject! { |p| p.score < winners.first.score }
    #update_channel_stats
    if winners.size > 1
      say Utils.comma_list(winners) + ' tie!'
      #winners.each { |p| update_user_stats(p, 1) }
    else
      say "#{winners.first} wins!"
      #update_user_stats(winners.first, 1)
    end
    #players.each { |p| update_user_stats(p, 0) unless winners.include?(p) }
    @plugin.remove_game(channel)
  end

  def get_player(user, source='')
    case user
    when NilClass
      return nil
    when User
      players.each do |p|
        return p if p.user == user
      end
    when String
      players.each do |p|
        return p if p.user.irc_downcase == user.irc_downcase(channel.casemap)
      end
      players.each do |p|
        if p.user.irc_downcase =~ /^#{user.irc_downcase(channel.casemap)}/
          return p unless p.user.irc_downcase == source.downcase
        end
      end
    else
      get_player(user.to_s)
    end
    return nil
  end

  def notify(player, msg, opts={})
    @bot.notice player.user, msg, opts
  end

  def processor(player, a)
    return unless player == players.first
    return if a.empty?
    return if player.discarded and player.drew
    unless player.discarded
      player.discarded = do_discard(player, a)
    else
      player.drew = do_draw(player, a)
    end
    do_turn if player.discarded and player.drew
  end

  def replace_player(replacer, a)
    old_player = new_player = nil
    a.each do |e|
      next if e == @bot.nick.downcase
      if old_player.nil?
        e = replacer.user.nick if e == 'me'
        old_player = channel.get_user(e)
      elsif new_player.nil?
        new_player = channel.get_user(e)
      end
    end
    unless old_player
      notify replacer, "Specify a replacement user, #{replacer.user}."
      return
    end
    # Player only specified one name. Assume that is the new player.
    unless new_player
      new_player = old_player
      old_player = channel.get_user(replacer.user.nick)
    end
    if replacer.user == new_player
      notify replacer, "You're already playing, #{replacer.user}."
    elsif old_player == new_player
      notify replacer, 'Replace someone with someone else.'
    elsif get_player(new_player.nick)
      notify replacer, "#{new_player.nick} is already playing #{Title}."
    elsif not player = get_player(old_player) # assign player or return nil
      notify replacer, "#{old_player} is not playing #{Title}."
    elsif player != replacer and replacer != manager
      notify replacer, 'Only game managers can replace other players.'
    else
      say "#{player} was replaced by #{Bold + new_player.nick + Bold}!"
      player.user = new_player
      say "#{player} is now game manager." if player == manager
    end
  end

  def say(msg, who=channel, opts={})
    return unless msg.is_a? String
    return if msg.empty?
    @bot.say who, msg, opts
  end

  def show_hand(p_array=players)
    [*p_array].each do |p|
      next if p.hand.empty?
      string = 'Cards: ' + p.hand.join(' , ')
      notify p, string
    end
  end

  def show_turn
    return unless started
    a, player = [], players.first
    string = "It's #{player}'s turn."
    unless last_discard.empty?
      string << ' Discard: ' + last_discard.join(', ')
    end
    say string
  end

  def start_game
    do_turn
  end

  def transfer_management(player, a)
    return if a.empty?
    unless player == manager
      notify player, "You can't transfer ownership. " +
                     "#{manager} manages this game."
      return
    end
    a.each do |e|
      break if new_manager = get_player(e, manager.user)
    end
    if new_manager.nil?
      say "#{player}: Specify another player."
      return
    elsif manager == new_manager
      say "#{player.user}: You are already game manager."
      return
    end
    @manager = new_manager
    say "#{new_manager} is now game manager."
  end

  def update_channel_stats
    r = @registry[:chan] || {}
    c = channel.name.downcase
    r[c] = {} if r[c].nil?
    r[c][:games] = r[c][:games].to_i + 1
    # display-name for proper caps
    r[c][:name] = channel.name
    r[c][:time] = r[c][:time].to_i + started
    @registry[:chan] = r
  end

  def update_user_stats(player, win)
    @registry[:user] = {} if @registry[:user].nil?
    c, n = channel.name.downcase, player.user.nick.downcase
    h1 = @registry[:chan][c][n] || {}
    h2 = @registry[:user][n] || {}
    [ h1, h2 ].each do |e|
      e[:games] = e[:games].to_i + 1
      # Get player's nick in proper caps.
      e[:nick] = player.user.to_s
      e[:wins] = e[:wins].to_i + win
    end
    r1 = @registry[:chan]
    r2 = @registry[:user]
    r1[c][n], r2[n] = h1, h2
    @registry[:chan], @registry[:user] = r1, r2
  end

end


class YanivPlugin < Plugin

  Title = Yaniv::Title

  Config.register Config::IntegerValue.new 'yaniv.jokers',
    :default => true,
    :desc => 'Disables Jokers when set to false.'

  Config.register Config::IntegerValue.new 'yaniv.countdown',
    :default => 10, :validate => Proc.new{|v| v > 0},
    :desc => 'Number of seconds before starting a game of Yaniv.'

  attr :games

  def initialize
    super
    @games = {}
  end

  def help(plugin, topic='')
    p = @bot.config['core.address_prefix'].first
    case topic.downcase
    when /drop/
      "Type 'drop me' to leave the game in progress, or " +
      "'drop <another player>' if you are the game manager."
    when /command/
      "In-game commands: 'p <card name>' to play a card, 'c' to display " +
      "hand cards, 't' to display current ture and discard, 'ti' to " +
      "show how much time has elapsed since the game started, 'drop me' " +
      "to leave a game in progress, 'replace [me with] user' to " +
      "have another player take your spot in the game.\n See '#{p}" +
      "help yaniv manage' for commands specific to the game manager."
    when /manage/, /transfer/, /xfer/
      'The player that starts the game is the game manager. Game ' +
      'managers may stop the game at any time, or transfer ownership ' +
      "by typing 'transfer [game to] <player>'. Managers may replace " +
      'themselves as well as other players in the game by typing ' +
      "'replace [me with] <user> / replace <player> [with] <nick>'"
    when /object/
      "Object of the game: Discard until the total value of your hand " +
      "cards is 5 or less. The game ends on the first player to call " +
      "yaniv, but the real winner is the player with the lowest score."
    when /rule/, /manual/
      "http://www.pagat.com/draw/yaniv.html"
    when /stat/, /scor/
      "'#{p}yaniv stats <channel/user>' displays the stats for a " +
      'channel or user. If no channel or user is specified, this command ' +
      "will show you your own stats.\n'#{p}yaniv stats <channel> " +
      "<user>' displays a user's stats for a specific channel.\n'#{p}yaniv " +
      "top <num> <channel>' shows the top <num> players for a given channel."
    when /cancel/, /end/, /halt/, /stop/
      "'#{p}yaniv stop' stops the current game; Only game " +
      'managers and bot owners can stop a game in progress.'
    when ''
      "#{Title}: commands, manual, object, stats, stop -- " +
      "Type '#{p}yaniv' to create a game."
    end
  end

  def create_game(m, p)
    if g = @games[m.channel]
      if m.source == g.manager.user
        m.reply "...you already started #{Title}."
      else
        m.reply "#{g.manager.user} already started #{Title}."
      end
      return
    end
    rounds = p[:rounds].to_i
    if rounds > 50 or rounds.zero?
      m.reply 'That\'s not a good idea...'
      return
    end
    @games[m.channel] = Yaniv.new(self, m.channel, m.source, rounds)
  end

  def message(m)
    return unless m.plugin and g = @games[m.channel]
    case m.message.downcase
    when 'j', 'jo', 'join'
      g.add_player(m.source)
    when 'ti', 'time'
      if g.started
        @bot.say m.replyto, Title + " has been in play for #{g.elapsed_time}."
      else
        m.reply Title + " hasn't started yet."
      end
    end
    # Messages only concerning players:
    player = g.get_player(m.source.nick)
    return unless player and g.started
    a = m.message.downcase.split(' ')[1..-1]
    case m.message.downcase
    when /^(ca?|cards?)( |\z)/
      g.show_hand(player)
    when /^drop( |\z)/
      g.drop_player(player, a)
    when /^(pi?|pl|play)( |\z)/
      g.processor(player, a)
    when /^(tu?|turn)( |\z)/
      g.show_turn
    when /^replace( |\z)/
      g.replace_player(player, a)
    when /^transfer( |\z)/
      g.transfer_management(player, a)
    end
  end

  def show_stats(m, params)
    if @registry[:chan].nil?
      m.reply "No #{Title} stats recorded yet."
      return
    end
    if params[:a] == false
      if @registry[:chan][m.channel.name.downcase]
        show_stats_chan(m, m.channel.name.downcase, params[:n].to_i)
      else
        m.reply "No one has played #{Title} in #{m.channel.name}."
      end
      return
    end
    a, chan, user, n = params[:a], nil, nil, 0
    if a.empty?
      user = m.source.nick.downcase
    else
      a.each do |e|
        chan = e.downcase if @registry[:chan][e.downcase]
        user = e.downcase if @registry[:user][e.downcase]
        n = e.to_i if e.to_i > n
      end
    end
    if chan.nil? and user.nil?
      # Check for missing # symbol.
      a.each { |e| chan = "##{chan}" if @registry[:chan]["##{chan}"] }
      if chan
        show_stats_chan(m, chan, n)
      else
        m.reply "No stats for #{a.join(' or ')}."
      end
    elsif user
      show_stats_user(m, user, chan)
    elsif chan
      show_stats_chan(m, chan, n)
    end
  end

  def show_stats_chan(m, chan, n)
    c = @registry[:chan][chan]
    if n.zero?
      str = "#{Bold}#{c[:name]}:#{Bold} #{c[:games]} games played, "
      str << "rounds played: #{c[:rounds]} "
      i = c[:games] > 1
      str << "(#{c[:rounds]/c[:games]} rounds average per game), " if i
      str << "time accumulated: #{Utils.secs_to_string(c[:time])} "
      str << "(#{Utils.secs_to_string(c[:time]/c[:games])} average per game)." if i
      @bot.say m.replyto, str
      return
    end
    n = 5 unless n.between?(1,20)
    tops = {}
    c.each_pair do |k, v|
      next unless k.is_a? String
      tops[v[:score]] = k
    end
    n = tops.size if n > tops.size
    @bot.say m.replyto, "#{c[:name]}'s top #{n} players:"
    i = 1
    if n.between?(1,8)
      tops.sort.reverse.each do |e|
        str = "#{Bold}#{i}.) #{c[e[1]][:nick]}#{Bold} - "
        str << "#{e.first} points, "
        str << "#{c[e[1]][:wins]}/#{c[e[1]][:games]} wins"
        @bot.say m.replyto, str
        i += 1
      end
    else
      str = ''
      tops.sort.reverse.each do |e|
        str << "#{Bold}#{i}.) #{c[e[1]][:nick]}#{Bold} - "
        str << "#{e.first} pts."
        i += 1
        if i > n
          break
        else
          str << ', '
        end
      end
      @bot.say m.replyto, str
    end
  end

  def show_stats_user(m, user, chan=nil)
    if chan
      u = @registry[:chan][chan][user]
      chan = @registry[:chan][chan][:name]
      str = "#{Bold}#{u[:nick]}#{Bold} (in #{chan}) -- "
    else
      u = @registry[:user][user]
      str = "#{Bold}#{u[:nick]}#{Bold} -- "
    end
    str << "score: #{u[:score]}, "
    str << "wins: #{u[:wins]}, "
    str << "games played: #{u[:games]}"
    @bot.say m.replyto, str
  end

  # Called from within the game.
  def remove_game(channel)
    if t = @games[channel].join_timer
      @bot.timer.remove(t)
    end
    @games.delete(channel)
  end

  def reset_everything(m, params)
    @registry.clear
    m.reply 'Registry cleared.'
  end

  def stop_game(m, plugin=nil)
    unless g = @games[m.channel]
      m.reply "No one is playing #{Title} here."
      return
    end
    player = @games[m.channel].get_player(m.source.nick)
    owner = @bot.auth.irc_to_botuser(m.source).owner?
    if g.manager == player or owner or not started
      remove_game(m.channel)
      @bot.say m.replyto, "#{Title} stopped."
    else
      m.reply 'Only game managers may stop the game.'
    end
  end

end

p = YanivPlugin.new

[ 'cancel', 'end', 'halt', 'stop' ].each do |x|
  p.map "yaniv #{x}",
    :action => :stop_game,
    :private => false
end
p.map 'yaniv reset everything',
  :action => :reset_everything,
  :auth_path => 'reset'
p.map 'yaniv stat[s] *a',
  :action => :show_stats,
  :defaults => {:a => [] }
p.map 'yaniv top [:n]',
  :action => :show_stats,
  :defaults => { :a => false, :n => 5 }
p.map 'yaniv [rounds] [:rounds]',
  :action => :create_game,
  :defaults => { :rounds => 1 },
  :private => false,
  :requirements => { :rounds => /^\d+$/ }

p.default_auth('*', true)
p.default_auth('reset', false)
