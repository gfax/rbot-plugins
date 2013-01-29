#-- vim:sw=2:et
#++
#
# :title: Dos, an Uno-based card game for rbot
#
# Author:: Giuseppe "Oblomov" Bilotta <giuseppe.bilotta@gmail.com>
# Author:: Jay Thomas <degradinglight@gmail.com>
# Copyright:: (C) 2012 Lite
#
# License:: GPL
# Version:: 2012-12-05
#
# TODO make bot playable

class DosGame
  COLORS = %w{Red Green Blue Yellow Silver}
  SPECIALS = %w{+1 +2 +2 +2 Reverse Reverse Reverse Skip Skip Skip}
  NUMERICS = %w{0 1 1 1 2 2 2 2 3 3 3 4 4 4 5 5 5 7 7 7 8 8}
  VALUES = NUMERICS + SPECIALS
  # Trash talk for players that exceed the time limit.
  REMARK = [ "forever.",
             "now to hoard all these W+4's to myself.",
             "FGT.",
             "becase you masturbate too much.",
             "you still da best mayne.",
             "kill youself.",
             "must be a fluke?",
             "next time try not to be gay.",
             "now we'll never get to see Rob again.",
             "go back to work.",
             "and now I'm pregnant.",
             "go get yourself a hot dog.",
             "go play Mars Matrix.",
             "here have a SEGA Saturn.",
             "now THAT's progressive.",
             "Who do you think you are? The Pope?",
             "you should become a professional idler, or pedophile, or something.",
             "What do you think this is? A ShamWow infomercial?",
             "Who do you think you are? John Madden?",
             "Who do you think you are? Johnny Bravo?",
             "Who do you think you are? John McClane?",
             "you're as cold as \00311ICE.",
             "you're as fantabulous as \0034E\0037L\0038T\0033O\0032N\003 " +
             "\0036J\0034\O\0037H\0038N\0033!\0032!\0036!",
           ]

  def DosGame.color_map(clr)
    case clr
    when 'Red'
      :red
    when 'Blue'
      :royal_blue
    when 'Green'
      :limegreen
    when 'Yellow'
      :yellow
    when 'Silver'
      :dark_gray
    when 'Wat'
      :olive
    end
  end

  def DosGame.irc_color_bg(clr)
    Irc.color([:white,:black][COLORS.index(clr)%2],DosGame.color_map(clr))
  end

  def DosGame.irc_color_fg(clr)
    Irc.color(DosGame.color_map(clr))
  end

  def DosGame.colorify(str, fg=false)
    ret = Bold.dup
    str.length.times do |i|
      ret << (fg ?
              DosGame.irc_color_fg(COLORS[i%5]) :
              DosGame.irc_color_bg(COLORS[i%5]) ) +str[i,1]
    end
    ret << NormalText
  end

  DOS = DosGame.colorify('DOS!', true)

  # Colored play cards
  class Card
    attr_reader :color
    attr_reader :value
    attr_reader :shortform
    attr_reader :to_s
    attr_reader :score

    def initialize(color, value)
      colors = %w{Red Green Blue Yellow Silver Wat}
      raise unless colors.include? color
      @color = color.dup
      raise unless VALUES.include? value
      if NUMERICS.include? value
        @value = value.to_i
        @score = value.to_i
      else
        @value = value.dup
        @score = 20
      end
      if @value == '+1' or @value == '+2'
        @shortform = (@color[0,1]+@value).downcase
      else
        @shortform = (@color[0,1]+@value.to_s[0,1]).downcase
      end
      @to_s = DosGame.irc_color_bg(@color) +
        Bold + ['', @color, @value, ''].join(' ') + NormalText
    end

    def picker
      if @value.to_s[0,1] == '+' # +1 & +2 cards
        return @value[1,1].to_i
      elsif @value.to_s[0,1] == 'f' # FF cards
        return 4
      else
        return 0
      end
    end

    def special?
      SPECIALS.include?(@value)
    end

    def <=>(other)
      cc = self.color <=> other.color
      if cc == 0
        return self.value.to_s <=> other.value.to_s
      else
        return cc
      end
    end
    include Comparable
  end

  # Wat cards: w+2, wr, ws
  class Wat < Card
    def initialize(value='+2')
      @color = 'Wat'
      @value = value.dup
      @shortform = if @value == '+2' then 'w'+value
        elsif @value == 'Reverse' then 'wr'
        else 'ws'
        end
      @score = 25
      @to_s = "\00300,07" + Bold + ['', @color, @value, ''].join(' ') + NormalText
    end
    def special?
      @value
    end
  end

  # Wild, Wild +4 cards
  class Wild < Card
    def initialize(value=nil)
      @color = 'Wild'
      raise if value and not value == '+4'
      if value
        @value = value.dup
        @shortform = 'w'+value
      else
        @value = nil
        @shortform = 'w'
      end
      @score = 50
      @to_s = DosGame.colorify(['', @color, @value, ''].compact.join(' '))
    end
    def special?
      @value
    end
  end

  # FFFFFF cards
  class Ffffff < Wild
    def initialize
      @color = 'Wild'
      @shortform = 'ff'
      @value = 'ff'
      @score = 50
      @to_s = DosGame.colorify(['', 'FFFFFF', ''].compact.join(' '))
    end
    def special?
      @value
    end
  end

  class Player
    attr_accessor :cards
    attr_accessor :user
    def initialize(user)
      @user = user
      @cards = []
    end
    def has_card?(short)
      has = []
      @cards.each { |c|
        has << c if c.shortform == short
      }
      if has.empty?
        return false
      else
        return has
      end
    end
    def to_s
      Bold + @user.to_s + Bold
    end
  end

  # cards in stock
  attr_reader :stock
  # current discard
  attr_reader :discard
  # previous discard, in case of challenge
  attr_reader :last_discard
  # channel the game is played in
  attr_reader :channel
  # list of players
  attr :players
  # true if the player picked a card (and can thus pass turn)
  attr_reader :player_has_picked_once
  # true if the player has picked two cards (and can thus no longer draw)
  attr_reader :player_has_picked_twice
  # number of cards to be picked if the player can't play an appropriate card
  attr_reader :picker

  # game start time
  attr :start_time

  # the IRC user that created the game
  attr_accessor :manager

  def initialize(plugin, channel, manager)
    @channel = channel
    @plugin = plugin
    @bot = plugin.bot
    @players = []
    @dropouts = []
    @discard = nil
    @last_discard = nil
    @value = nil
    @color = nil
    make_base_stock
    @stock = []
    make_stock
    @start_time = nil
    @join_timer = nil
    @turn_timer = nil
    @picker = 0 # Number of cards a player will draw
    @last_picker = 0
    @must_play = nil
    @manager = manager
    add_player(manager, true)
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

  def announce(msg, opts={})
    @bot.say channel, msg, opts
  end

  def notify(player, msg, opts={})
    @bot.notice player.user, msg, opts
  end

  def notify_error(player, msg, opts={})
    notify player, msg, opts
  end

  def make_base_stock
    @base_stock = COLORS.inject([]) do |list, clr|
      VALUES.each do |n|
        list << Card.new(clr, n)
      end
      list
    end
    # There's only 3 wat cards in a deck.
    @base_stock << Wat.new('+2')
    @base_stock << Wat.new('Reverse')
    @base_stock << Wat.new('Skip')
    6.times do
      @base_stock << Wild.new
    end
    5.times do
      @base_stock << Wild.new('+4')
    end
    3.times do
      @base_stock << Ffffff.new
    end
  end

  def make_stock
    @stock.replace @base_stock
    # Remove the cards in the players hand.
    @players.each { |p| p.cards.each { |c| @stock.delete_one c } }
    # Remove current top discarded card if present.
    if @discard
      @stock.delete_one(discard)
    end
    @stock.shuffle!
  end

  def start_game
    @join_timer = nil
    debug "Starting game"
    @players.shuffle!
    show_order
    announce "#{@players.first} deals the first card from the stock."
    card = @stock.shift
    @picker = 0
    @special = false
    while Wild === card or Ffffff === card do
      @stock.insert(rand(@stock.length), card)
      card = @stock.shift
    end
    set_discard(card)
    show_discard
    if @special
      do_special
    end
    next_turn
    @start_time = Time.now
  end

  def elapsed_time
    if @start_time
      Utils.secs_to_string(Time.now-@start_time)
    else
      "no time"
    end
  end

  def reverse_turn
    # If there are two players, the Reverse acts like a Skip, unless there's
    # a @picker running, in which case the Reverse should bounce the pick
    # on the other player. (Assuming 'dos.reverse_bounces' is set to true.)
    if @players.length > 2
      @players.reverse!
      # Put the current player back in place.
      @players.unshift @players.pop
      announce "Playing order was reversed!"
    elsif @picker > 1
      announce "#{@players.first} bounces the pick to #{@players.last}"
    else
      skip_turn
    end
  end

  def skip_turn
    @players << @players.shift
      # This is first and not last because the turn
      # change will be done by the following next_turn.
    announce "#{@players.first} skips a turn!"
  end

  def plus_one
    @players << @players.shift
    @picker = 0
    # Just skip the player since +1's can't be challenged.
    deal(@players.first, 1)
    announce "#{@players.first} drew a card!"
  end

  def do_special
    case @discard.value
    when 'Reverse'
      reverse_turn
      @special = false
    when 'Skip'
      skip_turn
      @special = false
    when '+1'
      plus_one
      @special = false
    end
  end

  def set_discard(card)
    @discard = card
    @value = card.value.dup rescue card.value
    if Wild === card
      @color = nil
    else
      @color = card.color.dup
    end
    if card.picker > 1
      @picker += card.picker
      @last_picker = @discard.picker
    end
    if card.special?
      @special = true
    else
      @special = false
    end
  end

  def next_turn(opts={})
    if @bot.config['dos.time_limit'] > 0
      if @turn_timer.nil?
        @turn_timer = @bot.timer.add_once(@bot.config['dos.time_limit']) {
          kick_player
        }
      else
        @bot.timer.reschedule(@turn_timer, @bot.config['dos.time_limit'])
      end
    end
    @must_play = nil
    @players << @players.shift
    @player_has_picked_once = false
    @player_has_picked_twice = false
    show_turn unless opts[:silent]
  end

  def can_play(card)
    # If play is forced, check against the only allowed cards.
    return false if @must_play and not @must_play.include?(card)

    if @picker > 1
      # During a picker run (i.e. after a +something was played and before a
      # player is forced to draw) you can only play pickers (+2, +4) and Reverse
      # if set. Reverse can be played if the previous card matches by color or
      # value (as usual), a +4 can always be played, a +2 can be played on a +2
      # of any color or on a Reverse of the correct color unless a +4 was
      # played on it.
      case card.value
      when 'Reverse'
        if @bot.config['dos.reverse.bounces'] == true
          # Reverse can be played if it matches color or value.
          return (card.color == @color) || (@discard.value == card.value)
        end
      when '+2'
        return false if @last_picker > 2
        return true if @discard.value == card.value
        if @bot.config['dos.reverse.bounces'] == true
          return true if @discard.value == 'Reverse' and @color == card.color
        end
        return false
      when '+4', 'ff'
        return true
      end
      return false
    else
      # You can always play a Wild
      return true if Wild === card
      # On a Wild, you must match the color
      if Wild === @discard
        return card.color == @color
      else
        # Otherwise, you can match either the value or the color
        return (card.value == @value) || (card.color == @color)
      end
    end
  end

  def ff?
    # Chances of FF backfiring on a player.
    if @value == 'ff'
      return true if rand(100) + 1 <= @bot.config['dos.ffffff_chances']
    end
    return false
  end

  def play_card(source, cards)
    debug "Playing card #{cards}"
    p = get_player(source)
    #shorts = cards.gsub(/\s+/,'').match(/^(?:([rbgysw]\+?\d)\1?|([rbgysw][rs])|(w(?:\+4)?)([rbgysw])?)$/).to_a
    shorts = cards.gsub(/\s+/,'').match(/^(?:([rbgysw]\+?\d)\1?{1,2}|([rbgysw][rs])|(w(?:\+4)?)([rbgysw])?)$/).to_a
    debug shorts.inspect
    if shorts.empty?
      shorts = cards.gsub(/\s+/,'').match(/^(?:([rbgysw]\+?\d)\1?{1,2}|([rbgysw][rs])|(f{2}?)([rbgysw])?)$/).to_a
      if shorts.empty?
        announce "wat cards?"
        return
      end
    end
    full = shorts[0]    # player input
    short = shorts[1] || shorts[2] || shorts[3] # normal | special | wild
    jolly = shorts[3]   # wild
    jcolor = shorts[4]  # wild color
    if jolly            # number of cards played
      toplay = 1
    else
      toplay = (full == short) ? 1 : 2
      if toplay == 2 and shorts[0] == shorts[1]*3
        toplay += 1
      end
    end
    debug [full, short, jolly, jcolor, toplay].inspect
    # If @color is nil, the player just played a wild without specifying
    # a color. He should now use "co <colorname>", but we allow him to
    # replay the wild _and_ specify the color, without actually replaying
    # the card (which would otherwise happen if the player has another wild).
    if @color.nil?
      if jcolor
        choose_color(p.user, jcolor)
      else
        announce "You already played your card, #{p}. Choose a color with: co r|b|g|y|s"
      end
      return
    end
    if shorts[0] == 'ws' && shorts[2] == 'ws'
      # This is a workaround to check whether a player has a 'Wat Skip' and if
      # not, then perhaps they meant to play a 'Wild' with the color 'Silver'.
      unless p.has_card?(short)
        cards, full, jolly, jcolor = 'w', 'w', 'w', 's'
        shorts = [ "w", nil, nil, "w", "s" ]
        short = shorts[1] || shorts[2] || shorts[3]
      end
    end
    if shorts[0] == 'wr' && shorts[2] == 'wr'
      # Same mishap with w r and 'Wat Reverse'.
      unless p.has_card?(short)
        cards, full, jolly, jcolor = 'w', 'w', 'w', 'r'
        shorts = [ "w", nil, nil, "w", "r" ]
        short = shorts[1] || shorts[2] || shorts[3]
      end
    end
    #announce "input: #{short} -- parsing: #{shorts}"
    if cards = p.has_card?(short)
      debug cards
      unless can_play(cards.first)
        notify_error p, "You can't play that card."
        return
      end
      if cards.length >= toplay
        # If the played card is a W+4 not played during a stacking +x
        # TODO if A plays an illegal W+4, B plays a W+4, should the next
        # player be able to challenge A? For the time being we say no,
        # but I think he should, and in case A's move was illegal
        # game would have to go back, A would get the penalty and replay,
        # while if it was legal the challenger would get 50% more cards,
        # i.e. 12 cards (or more if the stacked +4 were more). This would
        # only be possible if the first W+4 was illegal, so it wouldn't
        # apply for a W+4 played on a +2 anyway.
        #
        if @picker == 0 and Wild === cards.first and cards.first.value
          # Save the previous discard in case of challenge.
          @last_discard = @discard.dup
          # Save the color too, in case it was a Wild.
          @last_color = @color.dup
        else
          # Mark the move as not challengeable.
          @last_discard = nil
          @last_color = nil
        end
        set_discard(p.cards.delete_one(cards.shift))
        if toplay > 1
          set_discard(p.cards.delete_one(cards.shift))
          if toplay > 2
            set_discard(p.cards.delete_one(cards.shift))
            announce "%{p} plays %{card} %{b}thrice!%{b}" % {
              :p => p,
              :card => @discard,
              :b => Bold
            }
          else
            announce "#{p} plays #{@discard} twice!"
          end
        else
          announce "%{p} plays %{card}" % { :p => p, :card => @discard }
        end
        if p.cards.length == 2
          announce "#{p} has #{DOS}"
        elsif p.cards.length == 0
          end_game
          return
        end
        show_picker
        if @color
          if @special
            do_special
          end
          next_turn
        elsif jcolor
          choose_color(p.user, jcolor)
        else
          announce "%{p}, choose a color with: co r|b|g|y|s" % { :p => p }
        end
      else
        notify_error p, "You don't have two cards of that kind."
      end
    else
      notify_error p, "You don't have that card."
    end
  end

  def challenge
    return unless @last_discard
    # current player
    cp = @players.first
    # previous player
    lp = @players.last
    announce "#{cp} challenges #{lp}'s #{@discard}!"
    # Check if the previous player had a non-special card of the correct color.
    legal = true
    lp.cards.each do |c|
      if c.color == @last_color and not c.special?
        legal = false
        break
      end
    end
    if legal
      @picker += 2
      # In any situation, FF cards still have a chance of backfiring.
      victim = if ff? then lp else cp end
      announce "#{lp}'s move was legal, #{victim} must pick #{Bold}#{@picker}#{Bold} cards!"
      @last_color = nil
      @last_discard = nil
      deal(victim, @picker)
      @picker = 0
      next_turn
    else
      # No exceptions for FF's!!
      unless ff?
        victim = lp
        announce "#{lp}'s move was #{Bold}not#{Bold} legal, #{victim} must " +
                 "pick #{Bold}#{@picker}#{Bold} cards and play again!"
      else
        victim = cp
        announce "#{lp} must play another card, because that move was #{Bold}not#{Bold} legal, but " +
                   "#{victim} must pick #{Bold}#{@picker}#{Bold} cards because FFFFFF that crybaby."
      end
      played = @discard # store the misplayed W+4/FF
      # Reset the discard.
      @color = @last_color.dup
      @discard = @last_discard.dup
      @special = false
      @value = @discard.value.dup rescue @discard.value
      @last_color = nil
      @last_discard = nil
      # Force the player to play the current cards,
      @must_play = lp.cards.dup
      # but not the same (type of) card he misplayed though.
      @must_play.delete(played)
      lp.cards << played # Reinstate the W+4 in the list of player cards
      # Give him the penalty cards,
      deal(victim, @picker)
      @picker = 0
      # and restore the turn.
      @players.unshift @players.pop
    end
  end

  def pass(user)
    p = get_player(user)
    if @picker > 1
      unless ff?
        announce "#{p} passes turn, and has to draw #{Bold}#{@picker}#{Bold} cards!"
        deal(p, @picker)
      else
        victim = @players.last
        announce "#{p} passes turn, and #{victim} has to draw #{Bold}#{@picker}#{Bold} cards!"
        deal(victim, @picker)
      end
      @picker = 0
      # Make sure that if this is the "pick and pass" after a
      # W+4, then the following player cannot do a challenge.
      @last_discard = nil
      @last_color = nil
    else
      unless @player_has_picked_once
        announce "You need to draw a card first."
        return
      end
    end
    next_turn
  end

  def choose_color(user, color)
    # Player can only pick a color if the current color is unset.
    if @color
      announce "You can't pick a color now, #{get_player(user)}"
      return
    end
    case color
    when 'r'
      @color = 'Red'
    when 'b'
      @color = 'Blue'
    when 'g'
      @color = 'Green'
    when 'y'
      @color = 'Yellow'
    when 's'
      @color = 'Silver'
    when 'w'
      announce 'Choose one of the 5 basic colors: r|b|g|y|s'
    else
      announce 'What color is that?'
      return
    end
    announce 'Color is now %{c}' % {
      :c => DosGame.irc_color_bg(@color)+" #{@color} "
    }
    next_turn
  end

  def show_time
    if @start_time
      announce "This #{DOS} game has been going on for #{elapsed_time}."
    else
      announce "The game hasn't started yet."
    end
  end

  def show_order
    announce "#{DOS} playing turn: #{players.join(' ')}"
  end

  def show_turn(opts={})
    if @players.empty?
      announce "Nobody is playing #{DOS} yet!"
      return false
    end
    cards = true
    cards = opts[:cards] if opts.key?(:cards)
    player = @players.first
    announce "It's #{player}'s turn." unless @players.length < 2
    show_user_cards(player) if cards
  end

  def has_turn?(source)
    @start_time && (@players.first.user == source)
  end

  def show_picker
    if @picker > 1
      announce "Next player must respond correctly or " +
               "pick #{Bold}#{@picker}#{Bold} cards."
    end
  end

  def show_discard
    announce "Current discard: %{card} %{c}" % { :card => @discard,
      :c => (Wild === @discard) ? DosGame.irc_color_bg(@color) + " #{@color} " : nil
    }
    show_picker
  end

  def show_user_cards(player)
    p = Player === player ? player : get_player(player)
    return unless p
    notify p, "#{p.cards.join(' ')}"
  end

  def show_all_cards(u=nil)
    announce(@players.inject([]) { |list, p|
      list << [p, p.cards.length].join(': ')
    }.join(', '))
    if u
      show_user_cards(u)
    end
  end

  def pick_card(user)
    p = get_player(user)
    unless @player_has_picked_once
      announce "#{p} picks a card."
      deal(p, 1)
      @player_has_picked_once = true
    else
      announce "#{p} picks another card."
      deal(p, 1) 
      @player_has_picked_twice = true
    end
  end

  def deal(player, num=1)
    picked = []
    num.times do
      picked << @stock.delete_one
      if @stock.length == 0
        announce "Shuffling discarded cards."
        make_stock
        if @stock.length == 0
          announce "No more cards!"
          end_game # derp
        end
      end
    end
    picked.sort!
    notify player, "You picked #{picked.join(' ')}"
    player.cards += picked
    player.cards.sort!
  end

  def add_player(user, first_player=false)
    if p = get_player(user)
      announce "You're already in the game, #{p}."
      return
    end
    @dropouts.each do |dp|
      if dp.user == user
        announce "You dropped from the game, #{dp}, you can't get back in."
        return
      end
    end
    if @last_discard
      announce "You can't join now, #{user}, a #{@discard} " +
               "was just played. Wait until next turn."
      return
    end
    cards = 7
    if @start_time
      cards = (@players.inject(0) do |s, pl|
        s +=pl.cards.length
      end*1.0/@players.length).ceil
    end
    p = Player.new(user)
    @players << p
    if first_player
      announce "#{p} starts a game of #{DOS} Type 'jo' to join in."
    else
      announce "#{p} joins this game of #{DOS}"
    end
    deal(p, cards)
    return if @start_time
    if @join_timer
      @bot.timer.reschedule(@join_timer, 10)
    elsif @players.length > 1
      countdown = @bot.config['dos.countdown']
      announce "Game will start in #{Bold}#{countdown}#{Bold} seconds."
      @join_timer = @bot.timer.add_once(countdown) {
        start_game
      }
    end
  end

  def drop_player(nick)
    # A nick is passed because the original 
    # player might have left the channel.
    unless p = get_player(nick)
      announce "#{p} isn't playing #{DOS}"
      return
    end
    announce "#{p} gives up this game of #{DOS}"
    case @players.length
    when 2
      if @join_timer
        @bot.timer.remove(@join_timer)
        announce "Game start countdown stopped."
        @join_timer = nil
      end
      if p == @players.first
        next_turn :silent => @start_time.nil?
      end
      if @start_time
        end_game
        return
      end
    when 1
      end_game(true)
      return
    end
    debug @stock.length
    while p.cards.length > 0
      @stock.insert(rand(@stock.length), p.cards.shift)
    end
    debug @stock.length
    @dropouts << @players.delete_one(p)
  end

  # Kick players when they take too long to on their turn.
  def kick_player(player=@players.first)
    @turn_timer = nil
    announce "#{Bold}#{player.user}#{Bold}: You have been " +
             "dropped from #{DOS} ...#{REMARK.sample}"
    if @players.length >= 3
      next_turn if player == @players.first
      debug @stock.length
      while player.cards.length > 0
        @stock.insert(rand(@stock.length), player.cards.shift)
      end
      debug @stock.length
      @dropouts << @players.delete_one(player)
    else
      # Don't dump the kicked player's cards. We
      # need those to count the winner's earnings.
      debug @stock.length
      while @players.last.cards.length > 0
        @stock.insert(rand(@stock.length), @players.last.cards.shift)
      end
      debug @stock.length
      next_turn
      end_game
    end
  end

  def replace_player(old, new)
    user = channel.get_user(new) # the new user
    if not user
      announce "There is no '#{new}' here."
      return false
    end
    if pl = get_player(user)
      announce "#{pl} is already playing #{DOS} here."
      return false
    end
    # We scan the player list of the player with the old nick, instead
    # of using get_player, in case of IRC drops etc
    @players.each do |p|
      if p.user.nick == old
        p.user = user
        announce "%{p} takes %{b}%{old}%{b}'s place at %{dos}" % {
          :p => p, :b => Bold, :old => old, :dos => DOS
        }
        return true
      end
    end
    announce "%{b}%{old}%{b} isn't playing %{dos} here" % {
      :dos => DOS, :b => Bold, :old => old
    }
    return false
  end

  def end_game(halted = false)
    runtime = @start_time ? Time.now -  @start_time : 0
    if @join_timer
      @bot.timer.remove(@join_timer)
      announce "Game start countdown stopped."
      @join_timer = nil
    end
    if @turn_timer
      @bot.timer.remove(@turn_timer)
      @turn_timer = nil
    end
    if halted
      if @start_time
        announce "%{dos} game halted after %{time}." % {
          :time => elapsed_time.gsub(/\[|\]|"/,''),
          :dos => DOS
        }
      else
        announce "#{DOS} game halted before it could start."
      end
    else
      announce "%{dos} game finished after %{time}! The winner is %{p}." % {
        :time => elapsed_time.gsub(/\[|\]|\"/,''),
        :dos => DOS, :p => @players.first
      }
    end
    if @picker > 1 and not halted
      if @discard.value == 'Reverse'
        p = @players.last
      else
        p = @players[1]
      end
      announce "%{p} has to draw %{b}%{n}%{b} cards!" % {
        :p => p, :n => @picker, :b => Bold
      }
      deal(p, @picker)
      @picker = 0
    end
    score = @players.inject(0) do |sum, pl|
      if pl.cards.length > 0
        announce "%{p} still had %{cards}" % {
          :p => pl, :cards => pl.cards.join(' ')
        }
        sum += pl.cards.inject(0) do |cs, c|
          cs += c.score
        end
      end
      sum
    end

    closure = { :dropouts => @dropouts, :players => @players, :runtime => runtime }
    if not halted
      announce "%{p} wins %{b}%{score}%{b} dollahs." % {
        :p => @players.first, :score => score, :b => Bold
      }
      closure.merge!(:winner => @players.first, :score => score,
        :opponents => @players.length - 1)
    end

    @plugin.do_end_game(@channel, closure)
  end

end

# A won game: store score and number of opponents, so we can calculate
# an average score per opponent (requested by Squiddhartha)
define_structure :DosGameWon, :score, :opponents
# For each player we store the number of games played, the number of
# games forfeited, and an DosGameWon for each won game
define_structure :DosPlayerStats, :played, :forfeits, :won

class DosPlugin < Plugin
  attr :games
  def initialize
    super
    @games = {}
  end

  def help(plugin, topic="")
    case topic
    when 'commands'
      [
      "'jo' to join in",
      "'p/pl <card>' to play <card>: e.g. 'p g7' to play Green 7, or 'p rr' to play Red Reverse, or 'p y2y2y3' to play multiple Yellow 2 cards",
      "'dr' to draw a card",
      "'pa' to pass your turn",
      "'co <color>' to pick a color after playing a Wild: e.g. 'co g' to select Green (or 'pl w+4 g' to select the color when playing the Wild)",
      "'ca' to show current cards",
      "'cd' to show the current discard",
      "'ch' to challenge a Wild +4",
      "'od' to show the playing order",
      "'ti' to show play time",
      "'tu' to show whose turn it is"
    ].join("; ")
    when /ch(alleng(e|ing))?/
      "A Wild +4 can only be played legally if you don't have normal (not special) cards of the current color. " +
      "The next player can challenge a W+4 by using the 'ch' command. " +
      "If the W+4 play was illegal, the player who played it must pick the W+4, pick 4 cards from the stock, and play a legal card. " +
      "If the W+4 play was legal, the challenger must pick 6 cards instead of 4."
    when 'rules'
      "Play all your cards, one at a time, by matching either the color or the value of the currently discarded card. " +
      "Cards with special effects: Skip (next player skips a turn), Reverse (reverses the playing order), +2 (next player has to take 2 cards). " +
      "Wilds can be played on any card, and you must specify the color for the next card. " +
      "Wild +4 also forces the next player to take 4 cards, but it can only be played if you can't play a color card. " +
      "You can play another +2 or +4 card on a +2 card, and a +4 on a +4, forcing the first player who can't play one to draw the cumulative sum of all cards. " +
      "You can also play a Reverse on a +2 or +4, bouncing the effect back to the previous player (that now comes next). "
    when /scor(?:e|ing)/, /dollahs?/
      [
      "The dollahs won with a game of %{dos} are totalled from the cards remaining in the hands of the other players.",
      "Each normal (not special) card is worth its face value in dollahs.",
      "Each colored special card (+2, Reverse, Skip) is worth 20 dollahs.",
      "Each Wild,  Wild +4, and FFFFFF card is worth 50 dollahs.",
      help(plugin, 'top'),
      help(plugin, 'topwin'),
      ].join(" ") % { :dos => DosGame::DOS }
    when 'top'
      "You can see the scoring table with #{Bold}'dos top N'#{Bold} where N is the number of top scores to show."
    when 'topwin'
      "You can see the winners table with #{Bold}'dos topwin N'#{Bold} where N is the number of top winners to show."
    when /cards?/
      [
      "There are 5 base colors (Red, Green, Blue, Yellow, Silver) and 160 %{dos} cards total: 0(1), 1(3), 2(4), 3(3), 4(3), 5(3), 7(3), 8(2), +1(1), +2(3), Reverse(3), Skip(3) for each color.",
      "There are six Wild, five Wild +4 cards, three FFFFFF cards, and three Wat cards."
      ].join(" ") % { :dos => DosGame::DOS }
    when 'admin'
      "The game manager (the user that started the game) can execute the following commands to manage it: " +
      [
      "'dos drop <user>' to drop a user from the game (any user can drop itself using 'dos drop')",
      "'dos replace <old> [with] <new>' to replace a player with someone else (useful in case of disconnects)",
      "'dos transfer [to] <nick>' to transfer game ownership to someone else",
      "'dos end' to end the game before its natural completion"
      ].join("; ")
    else
      _("%{dos} game. !dos to start a game. see 'help dos rules' for the rules, 'help dos admin' for admin commands, 'help dos score' for scoring rules. In-game commands: %{cmds}.") % {
        :dos => DosGame::DOS,
        :cmds => help(plugin, 'commands')
      }
    end
  end

  Config.register Config::IntegerValue.new('dos.countdown',
    :default => 20, :validate => Proc.new{|v| v > 2},
    :desc => "Seconds before starting a DOS! game after two players haved joined.")

  Config.register Config::IntegerValue.new('dos.ffffff_chances',
    :default => 35, :validate => Proc.new{|v| v > 0},
    :desc => "Chances (in percentage) of FFFFFF cards backfiring.")

  Config.register Config::BooleanValue.new('dos.reverse_bounces',
    :default => true,
    :desc => "When true, Reverse cards can bounce Draw +2 " +
             "cards back to the person that played them.")

  Config.register Config::IntegerValue.new('dos.time_limit',
    :default => 0,
    :desc => "Seconds alotted each turn before dropping a player from the game. Set to 0 to disable.")

  def message(m)
    return unless @games.key?(m.channel)
    return unless m.plugin # skip messages such as: <someuser> botname,
    g = @games[m.channel]
    replied = true
    case m.plugin.intern.downcase
    when /^j(o|oin)?\b/ # join game
      return if m.params
      g.add_player(m.source)
    when /^pe\b/, /^d(r|raw)?\b/ # pick card
      return if m.params
      if g.has_turn?(m.source)
        if g.player_has_picked_twice
          m.reply "You already picked two cards."
        elsif g.picker > 1
          g.pass(m.source)
        else
          g.pick_card(m.source)
        end
      end
    when /^pa(ss)?\b/ # pass turn
      return if m.params or not g.start_time
      if g.has_turn?(m.source)
        g.pass(m.source)
      end
    when /^p(l|lay)?\b/ # play card
      if g.has_turn?(m.source)
        g.play_card(m.source, m.params.downcase)
      else
        m.reply "It's not your turn."
      end
    when /^co(lor)?\b/ # pick color
      if g.has_turn?(m.source)
        g.choose_color(m.source, m.params.downcase)
      end
    when /^ca?(rds)?\b/ # show current cards
      return if m.params
      g.show_all_cards(m.source)
    when /^cd\b/ # show current discard
      return if m.params or not g.start_time
      g.show_discard
    when /^ch(allenge)?\b/
      if g.has_turn?(m.source)
        if g.last_discard
          g.challenge
        else
          m.reply "Previous move cannot be challenged."
        end
      end
    when /^o(d|rder)?\b/ # show playing order
      return if m.params
      g.show_order
    when /^t(i|me)?\b/ # show play time
      return if m.params
      g.show_time
    when /^t(u|urn)?\b/ # show whose turn is it
      return if m.params
      if g.has_turn?(m.source)
        m.reply "It's your turn, nigga."
      else
        g.show_turn(:cards => false)
      end
    else
      replied=false
    end
    m.replied=true if replied
  end

  def create_game(m, p)
    if @games.key?(m.channel)
      m.reply "There is already a %{dos} game running here, managed by %{who}. say 'jo' to join in" % {
        :who => @games[m.channel].manager,
        :dos => DosGame::DOS
      }
      return
    end
    @games[m.channel] = DosGame.new(self, m.channel, m.source)
    @bot.auth.irc_to_botuser(m.source).set_temp_permission('dos::manage', true, m.channel)
  end

  def transfer_ownership(m, p)
    unless @games.key?(m.channel)
      m.reply "There is no %{dos} game running here" % { :dos => DosGame::DOS }
      return
    end
    g = @games[m.channel]
    old = g.manager
    new = m.channel.get_user(p[:nick])
    if new
      g.manager = new
      @bot.auth.irc_to_botuser(old).reset_temp_permission('dos::manage', m.channel)
      @bot.auth.irc_to_botuser(new).set_temp_permission('dos::manage', true, m.channel)
      m.reply "%{dos} game ownership transferred from %{old} to %{nick}" % {
        :dos => DosGame::DOS, :old => old, :nick => p[:nick]
      }
    else
      m.reply "Who is this %{nick} you want me to transfer game ownership to?" % p
    end
  end

  def end_game(m, p)
    unless @games.key?(m.channel)
      return
    end
    @games[m.channel].end_game(true)
  end

  def cleanup
    @games.each { |k, g| g.end_game(true) }
    super
  end

  def chan_reg(channel)
    @registry.sub_registry(channel.downcase)
  end

  def chan_stats(channel)
    stats = chan_reg(channel).sub_registry('stats')
    class << stats
      def store(val)
        val.to_i
      end
      def restore(val)
        val.to_i
      end
    end
    stats.set_default(0)
    return stats
  end

  def chan_pstats(channel)
    pstats = chan_reg(channel).sub_registry('players')
    pstats.set_default(DosPlayerStats.new(0,0,[]))
    return pstats
  end

  def do_end_game(channel, closure)
    reg = chan_reg(channel)
    stats = chan_stats(channel)
    stats['played'] += 1
    stats['played_runtime'] += closure[:runtime]
    if closure[:winner]
      stats['finished'] += 1
      stats['finished_runtime'] += closure[:runtime]

      pstats = chan_pstats(channel)

      closure[:players].each do |pl|
        k = pl.user.downcase
        pls = pstats[k]
        pls.played += 1
        pstats[k] = pls
      end

      closure[:dropouts].each do |pl|
        k = pl.user.downcase
        pls = pstats[k]
        pls.played += 1
        pls.forfeits += 1
        pstats[k] = pls
      end

      winner = closure[:winner]
      won = DosGameWon.new(closure[:score], closure[:opponents])
      k = winner.user.downcase
      pls = pstats[k] # already marked played +1 above
      pls.won << won
      pstats[k] = pls
    end

    @bot.auth.irc_to_botuser(@games[channel].manager).reset_temp_permission('dos::manage', channel)
    @games.delete(channel)
  end

  def do_chanstats(m, p)
    stats = chan_stats(m.channel)
    np = stats['played']
    nf = stats['finished']
    if np > 0
      str = "%{nf} %{dos} games completed over %{np} games played. " % {
        :np => np, :dos => DosGame::DOS, :nf => nf
      }
      cgt = stats['finished_runtime']
      tgt = stats['played_runtime']
      str << "%{cgt} game time for completed games" % {
        :cgt => Utils.secs_to_string(cgt)
      }
      if np > nf
        str << " on %{tgt} total game time. " % {
          :tgt => Utils.secs_to_string(tgt)
        }
      else
        str << ". "
      end
      str << "%{avg} average game time for completed games" % {
        :avg => Utils.secs_to_string(cgt/nf)
      }
      str << ", %{tavg} for all games" % {
        :tavg => Utils.secs_to_string(tgt/np)
      } if np > nf
      m.reply str
    else
      m.reply "Nobody has played %{dos} on %{chan} yet." % {
        :dos => DosGame::DOS, :chan => m.channel
      }
    end
  end

  def do_pstats(m, p)
    dnick = p[:nick] || m.source # display-nick, don't later case
    nick = dnick.downcase
    ps = chan_pstats(m.channel)[nick]
    if ps.played == 0
      m.reply "%{nick} never played %{dos} here" % {
        :dos => DosGame::DOS, :nick => dnick
      }
      return
    end
    np = ps.played
    nf = ps.forfeits
    nw = ps.won.length
    score = ps.won.inject(0) { |sum, w| sum += w.score }
    str = "%{nick} played %{np} %{dos} games here, " % {
      :nick => dnick, :np => np, :dos => DosGame::DOS
    }
    str << "forfeited %{nf} games, " % { :nf => nf } if nf > 0
    str << "won %{nw} games" % { :nw => nw}
    if nw > 0
      str << " with %{score} total dollahs" % { :score => score }
      avg = ps.won.inject(0) { |sum, w| sum += w.score/w.opponents }/nw
      str << " and an average of %{avg} dollahs per opponent" % { :avg => avg }
    end
    m.reply str
  end

  def replace_player(m, p)
    unless @games.key?(m.channel)
      m.reply "There is no #{DosGame::DOS} game running here"
      return
    end
    @games[m.channel].replace_player(p[:old], p[:new])
  end

  def drop_player(m, p)
    unless @games.key?(m.channel)
      m.reply "There is no #{DosGame::DOS} game running here."
      return
    end
    @games[m.channel].drop_player(p[:nick] || m.source.nick)
  end

  def print_stock(m, p)
    unless @games.key?(m.channel)
      m.reply "There is no #{DosGame::DOS} game running here."
      return
    end
    stock = @games[m.channel].stock
    m.reply "#{stock.length} cards in stock."
  end

  def do_top(m, p)
    pstats = chan_pstats(m.channel)
    scores = []
    wins = []
    pstats.each do |k, v|
      wins << [v.won.length, k]
      scores << [v.won.inject(0) { |s, w| s+=w.score }, k]
    end

    if wins.empty?
      m.reply "No #{DosGame::DOS} games were completed here."
      return
    end


    if n = p[:scorenum]
      msg = "%{dos} %{num} highest scores: " % {
        :dos => DosGame::DOS, :num => p[:scorenum]
      }
      scores.sort! { |a1, a2| -(a1.first <=> a2.first) }
      scores = scores[0, n.to_i].compact
      i = 0
      if scores.length <= 5
        list = "\n" + scores.map { |a|
          i+=1
          "%{i}. %{b}%{nick}%{b} with %{b}%{score}%{b} dollahs" % {
            :i => i, :b => Bold, :nick => a.last, :score => a.first
          }
        }.join("\n")
      else
        list = scores.map { |a|
          i+=1
          "%{i}. %{nick} ( %{score} )" % {
            :i => i, :nick => a.last, :score => a.first
          }
        }.join(" | ")
      end
    elsif n = p[:winnum]
      msg = "%{dos} %{num} most wins: " % {
        :dos => DosGame::DOS, :num => p[:winnum]
      }
      wins.sort! { |a1, a2| -(a1.first <=> a2.first) }
      wins = wins[0, n.to_i].compact
      i = 0
      if wins.length <= 5
        list = "\n" + wins.map { |a|
          i+=1
          "%{i}. %{b}%{nick}%{b} with %{b}%{score}%{b} wins" % {
            :i => i, :b => Bold, :nick => a.last, :score => a.first
          }
        }.join("\n")
      else
        list = wins.map { |a|
          i+=1
          "%{i}. %{nick} ( %{score} )" % {
            :i => i, :nick => a.last, :score => a.first
          }
        }.join(" | ")
      end
    else
      msg = "What kind of score list did you want?"
      list = " I can only show the top scores (with top) and the most wins (with topwin)"
    end
    m.reply msg + list, :max_lines => (msg+list).count("\n")+1
  end
end

p = DosPlugin.new
p.map 'dos', :private => false, :action => :create_game
p.map 'dos cancel', :private => false, :action => :end_game, :auth_path => 'manage'
p.map 'dos end', :private => false, :action => :end_game, :auth_path => 'manage'
p.map 'dos stop', :private => false, :action => :end_game, :auth_path => 'manage'
p.map 'halt', :private => false, :action => :end_game, :auth_path => 'manage'
p.map 'dos stock', :private => false, :action => :print_stock
p.map 'dos chanstats', :private => false, :action => :do_chanstats
p.map 'dos stats [:nick]', :private => false, :action => :do_pstats
p.map 'dos top :scorenum', :private => false, :action => :do_top, :defaults => { :scorenum => 5 }
p.map 'dos topwin :winnum', :private => false, :action => :do_top, :defaults => { :winnum => 5 }
p.map 'dos drop',
  :private => false,
  :action => :drop_player,
  :auth_path => 'manage::drop::self!'
p.map 'dos giveup',
  :private => false,
  :action => :drop_player,
  :auth_path => 'manage::drop::self!'
p.map 'dos drop :nick',
  :private => false,
  :action => :drop_player,
  :auth_path => 'manage::drop::other!'
p.map 'dos replace :old [with] :new',
  :private => false,
  :action => :replace_player,
  :auth_path => 'manage'
p.map 'dos transfer [game [ownership]] [to] :nick',
  :private => false,
  :action => :transfer_ownership,
  :auth_path => 'manage'

p.default_auth('manage', false)
p.default_auth('manage::drop::self', true)
