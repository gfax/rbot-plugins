#-- vim:sw=2:et
#++
#
# :title: Kalah
#
# Author:: Lite <degradinglight@gmail.com>
# Copyright:: (C) 2012 gfax.ch
# License:: GPL
# Version:: 2012-06-29
#

class KalahPlugin < Plugin

  KHash = Struct.new(:c0, :c1, :c2, :c3, :c4, :c5, :c6, :c7, :c8, :c9, :c10, :c11, :c12, :c13)

  Config.register Config::BooleanValue.new('kalah.capture_leftovers',
    :default => true,
    :desc => "If a player has no more moves, the other player gets to keep " +
             "all the remaining seeds in play. Set to false to disable this.")

  Config.register Config::BooleanValue.new('kalah.clockwise',
    :default => true,
    :desc => "Seeds move clockwise when set to true, and counter-clockwise " +
             "when false. Counter-clockwise movement allows more seeds to " +
             "land in your mancala, but clockwise focuses on capturing." )

  Config.register Config::BooleanValue.new('kalah.go_again',
    :default => true,
    :desc => "Player gets another turn when landing in his mancala. It is " +
             "recommended setting this to false when playing counter-clockwise.")

  Config.register Config::IntegerValue.new('kalah.seeds',
    :default => 4, :validate => Proc.new{|v| v.between?(3,12)},
    :desc => "Default number of starting seeds per cup. " +
             "(Must be set to a number between 3 and 12.)")

  def help(plugin, topic="")
    case (topic.intern rescue nil)
    when /bo(t|ts)/i
      "!#{plugin} bot [seeds] -- starts a game vs the bot"
    when /objec(t|tive|tives)/i
      "The objective of the game is to capture more seeds than one's opponent. The " +
      "game ends when all seeds are captured or a player runs out of seeds to move."
    when /pla(y|ying)/i
      "Player 1 controls the top six \"cups\" while player 2 controls the bottom " +
      "six. The empty cup on the top row represents player 1's mancala while the " +
      "bottom, empty cup represents player 2's mancala. Captured seeds are " +
      "collected here and cannot be moved. Seeds can be moved from cups 1-6 " +
      "by typing a number, (i.e., 3 to move the seeds out of the third cup.)"
    when /rules/i
      "On a turn, the player removes all seeds from one of the cups under his control. Moving " +
      "#{@bot.config['kalah.clockwise'] ? 'clockwise':'counter-clockwise'}, the " +
      "player drops one seed in each cup in turn, including the player's own manacala, but not " +
      "his opponent's. If the last sown seed lands in the player's mancala, the player gets an " +
      "additional move. If the last sown seed lands in an empty house, and the opposite house " +
      "contains seeds, both the last seed and the seeds opposite are captured and placed into " +
      "the player's mancala."
    when /sta(t|ts)/i, /scor(e|es|ing)/i
      "!#{plugin} stats <channel|user> -- displays the stats and scores for a channel or " +
      "user. If no channel or user is specified, this command will show you your own stats."
    when /sto(p|pping)/i, /cance(l|ling)/i, /en(d|ding)/i
      "!#{plugin} stop -- stops the current game"
    else
      "Kalah, an American variant of Mancala. !#{plugin} [seeds] -- starts a game of Kalah with " +
      "the given number of seeds. Other help topics: bot, objective, playing, rules, stats, stop"
    end
  end

  def bot_move(m, chan)
    # Capture any exposed seeds you see
    cup = bot_move_capture(chan)
    # Else move into your mancala
    cup = bot_move_mancala(chan) if cup == 0
    # Move any exposed seeds that
    # are prone to being captured
    cup = bot_move_exposed(chan) if cup == 0
    # Just do whatever!
    cup = bot_move_available(chan) if cup == 0
    cup = opposite(cup)
    m.reply "#{@cl2}#{cup}"
    move(m, chan, 2, cup)
  end

  def bot_move_available(chan)
    move, n, = 0, 13
    while n > 7
      move = n unless empty?(chan, n)
      n -= 1
    end
    move
  end

  def bot_move_capture(chan)
    move = 0
    if clockwise?
      n = 8
      while n < 14
        unless empty?(chan, n)
          if @board[chan][n] < opposite(n)
            move = n if @board[chan][@board[chan][n] + n] == 0
          elsif @board[chan][@board[chan][n] - opposite(n) + 1] == 0
            move = n
          else
          end
        end
        n += 1
      end
    else
      n = 13
      while n > 7
        unless empty?(chan, n)
          move = n if @board[chan][n - @board[chan][n]%13] == 0
        end
        n -= 1
      end
    end
    move
  end

  def bot_move_exposed(chan)
    move, n = 0, 13
    while n > 7
      if !empty?(chan, n) && @board[chan][opposite(n)] == 0
        move = n
      end
      n -= 1
    end
    move
  end

  def bot_move_mancala(chan)
    move = 0
    if clockwise?
      n = 13
      while n > 7
        if !empty?(chan, n) && (@board[chan][n] - opposite(n) + 1)%13 == 7
          move = n
        end
        n -= 1
      end
    else
      n, x = 8, 1
      while n < 14
        move = n if !empty?(chan, n) && @board[chan][n]%13 == x
        n += 1
        x += 1
      end
    end
    move
  end

  def capture_leftovers(chan)
    (1..6).each do |pos|
      @board[chan][0] += @board[chan][pos]
      @board[chan][pos] = 0
    end
    (8..13).each do |pos|
      @board[chan][7] += @board[chan][pos]
      @board[chan][pos] = 0
    end
  end

  def clear(m, chan)
    @board[chan] = nil
    @player1[chan] = nil
    @player2[chan] = nil
    @turn[chan] = nil
    @winner[chan] = nil
  end

  def clockwise?
    @bot.config['kalah.clockwise']
  end

  def display(m, chan)
   b = KHash.new(*@board[chan] )
   s = " #{Bold}\00314|\003#{Bold}"
   # Using .join breaks IRC colors,
   # so let's just make a big mess.
   m.reply "#{@cl1}#{b.c0}\003 #{b.c0 > 9 ? '' : ' '}" +
           "#{b.c1 > 9 ? '' : ' '}#{b.c1}#{s}" +
           "#{b.c2 > 9 ? '' : ' '}#{b.c2}#{s}" +
           "#{b.c3 > 9 ? '' : ' '}#{b.c3}#{s}" +
           "#{b.c4 > 9 ? '' : ' '}#{b.c4}#{s}" +
           "#{b.c5 > 9 ? '' : ' '}#{b.c5}#{s}" +
           "#{b.c6 > 9 ? '' : ' '}#{b.c6}"
   m.reply "#{b.c13 > 9 ? '' : ' '} \003 \003 #{b.c13}#{s}" +
           "#{b.c12 > 9 ? '' : ' '}#{b.c12}#{s}" +
           "#{b.c11 > 9 ? '' : ' '}#{b.c11}#{s}" +
           "#{b.c10 > 9 ? '' : ' '}#{b.c10}#{s}" +
           "#{b.c9 > 9 ? '' : ' '}#{b.c9}#{s}" +
           "#{b.c8 > 9 ? '' : ' '}#{b.c8}" +
           "#{b.c7 > 9 ? '' : ' '}  #{@cl2}#{b.c7}\003"
  end

  def draw?(chan)
    if @board[chan][0] == @board[chan][7]
      return true
    end
    return false
  end

  def empty?(chan, cup)
    if @board[chan][cup] == 0
      return true
    end
    return false
  end

  def get_chan(m)
    if m.public?
      m.channel.name.downcase
    else m.sourcenick.downcase
    end
  end

  def message(m)
    return if @player1.nil? or @turn.nil?
    chan = get_chan(m)
    return if @turn[chan].nil?
    if m.message.match(/^jo\b/i)
      return if @player2.nil?
      return unless @player2[chan] == true
      @player2[chan] = m.sourcenick
      m.reply "#{@cl1}#{@player1[chan]}\003 is first. Second player is " +
              "#{@player1[chan] == @player2[chan] ? 'also ' : ''}#{@cl2}#{@player2[chan]}\003."
      play(m, chan)
    end
    return unless m.message.match(/^\d\b/i)
    if @turn[chan] == 1
      return unless @player1[chan] == m.sourcenick
      player = 1
    elsif @turn[chan] == 2
      return unless @player2[chan] == m.sourcenick
      player = 2
    else return
    end
    cup = m.message[0].to_i
    unless valid_move?(cup)
      m.reply "That's not a valid move."
      return
    end
    move(m, chan, player, cup)
  end

  def move(m, chan, player, cup)
    if player == 2
      pos = opposite(cup)
    else pos = cup
    end
    if empty?(chan, pos)
      m.reply "There are no seeds in that cup."
      return
    end
    # Move the seeds
    seeds = @board[chan][pos]
    @board[chan][pos] = 0
    until seeds == 0
      if clockwise?
        pos += 1
      else
        pos -= 1
      end
      pos = 0 if pos > 13
      pos = 13 if pos < 0
      unless pos == 0 && player == 2
        unless pos == 7 && player == 1
          @board[chan][pos] = @board[chan][pos] + 1
          seeds -= 1
        end
      end
    end
    # Capture seeds?
    if @board[chan][pos] == 1 && !on_mancala?(pos)
      if player == 1
        @board[chan][0] = @board[chan][0] + @board[chan][opposite(pos)] + 1
      else
        @board[chan][7] = @board[chan][7] + @board[chan][opposite(pos)] + 1
      end
      @board[chan][pos] = 0
      @board[chan][opposite(pos)] = 0
    end
    if on_mancala?(pos) && @bot.config['kalah.go_again']
      # Player gets to go again for landing in own mancala.
      @turn[chan] = @turn[chan] + 2
    end
    play(m, chan)
  end

  def new_game(m, params)
    chan = get_chan(m)
    @cl1 = "\00312" if @cl1.nil?
    @cl2 = "\00304" if @cl2.nil?
    @player1 = Hash.new if @player1.nil?
    return unless @player1[chan].nil?
    @player2 = Hash.new if @player2.nil?
    @player1[chan] = m.sourcenick
    @turn = Hash.new if @turn.nil?
    @turn[chan] = 0
    @board = Hash.new if @board.nil?
    s = if params[:seeds].to_i.between?(3,12)
          params[:seeds].to_i
        else
          @bot.config['kalah.seeds'].to_i
        end
    @board[chan] = [ 0, s, s, s, s, s, s, 0, s, s, s, s, s, s ]
    if params[:bot_player] == true
      @player2[chan] = @bot.nick
      play(m, chan)
    else
      @player2[chan] = true
      m.reply "Kalah has been initiated. Type 'jo' to join."
    end
  end

  def no_moves?(chan)
    if @turn[chan] == 1 or @turn[chan] == 3
      cup, last = 1, 7
    else
      cup, last = 8, 14
    end
    while cup < last
      return false if @board[chan][cup] > 0
      cup += 1
    end
    return true
  end

  def on_mancala?(cup)
    return true if cup == 0 or cup == 7
    return false
  end

  def opposite(cup)
    case cup
      when 1 then 13
      when 2 then 12
      when 3 then 11
      when 4 then 10
      when 5 then 9
      when 6 then 8
      when 8 then 6
      when 9 then 5
      when 10 then 4
      when 11 then 3
      when 12 then 2
      when 13 then 1
    end
  end

  def play(m, chan)
    if @turn[chan] == 1
      @turn[chan] = 2
    elsif @turn[chan] == 2 or @turn[chan] == 0
      @turn[chan] = 1
    else
    end
    if no_moves?(chan)
      won(m, chan)
      return
    end
    if @turn[chan] > 2
      @turn[chan] = @turn[chan] - 2
      if @turn[chan] == 2 && @player2[chan] == @bot.nick
        m.reply "I landed in my mancala, EHEHehehe."
      else
        m.reply "You landed in your mancala. Go again."
      end
    else
      m.reply "#{@turn[chan] == 1 ? @cl1 : @cl2}Player #{@turn[chan]}\003's turn:"
    end
    display(m, chan)
    if @turn[chan] == 2 && @player2[chan] == @bot.nick
      @bot.timer.add_once(2) { bot_move(m, chan) }
    end
  end

  def reset_everything(m, params)
    @registry.clear
    m.reply "You ruined EVERYTHING."
  end

  def show_stats(m, params)
    if params[:x][0].to_s == "#"
      chan = params[:x].downcase
      if @registry.has_key? chan
        m.reply "#{chan}: #{@registry[chan][0]} games played, " +
        "#{@registry[chan][1]} wins, #{@registry[chan][2]} draws."
      else m.reply "No stats."
      end
      return
    end
    user = if params[:x] == "x" then "n" + m.sourcenick.downcase
           else "n" + params[:x].downcase
           end
    if @registry.has_key? user
      m.reply "#{@registry[user][0]}: #{@registry[user][1]} games played, " +
      "#{@registry[user][2]} wins, #{@registry[user][3]} losses."
    else m.reply "No stats for THAT guy..."
    end
  end

  def stop(m, params)
    m.okay
    chan = get_chan(m)
    clear(m, chan)
  end

  def update_chan_stats(chan, win, draw)
    if @registry.has_key? chan
      @registry[chan] = [ @registry[chan][0] + 1,
                          @registry[chan][1] + win,
                          @registry[chan][2] + draw ]
    else @registry[chan] = [1, win, draw]
    end
  end

  def update_user_stats(chan, player, win, lose)
    user = "n" + player.downcase
    if @registry.has_key? user
      # Update user stats - [Nick, Games, Wins, Losses]
      @registry[user] = [ player,
                          @registry[user][1].to_i + 1,
                          @registry[user][2].to_i + win,
                          @registry[user][3].to_i + lose ]
    else # else, write a new record for the new user.
      @registry[user] = [player, 1, win, lose]
    end
  end

  def update_stats(m, chan)
    if @winner[chan] > 0
      update_chan_stats(chan, 1, 0) if m.public?
      if @winner[chan] == 1
        update_user_stats(chan, @player1[chan], 1, 0)
        update_user_stats(chan, @player2[chan], 0, 1) unless @player2[chan].nil?
      else
        update_user_stats(chan, @player1[chan], 0, 1)
        update_user_stats(chan, @player2[chan], 1, 0) unless @player2[chan].nil?
      end
    else
      update_chan_stats(chan, 0, 1) if m.public?
      update_user_stats(chan, @player1[chan], 0, 0)
      update_user_stats(chan, @player2[chan], 0, 0) unless @player2[chan].nil?
    end
    clear(m, chan)
  end

  def valid_move?(cup)
    if cup.between?(1,6)
      return true
    end
    return false
  end

  def won(m, chan)
    capture_leftovers(chan) if @bot.config['kalah.capture_leftovers']
    @winner = Hash.new if @winner.nil?
    if @board[chan][0] == @board[chan][7]
      m.reply "It's a tie!"
      @winner[chan] = 0
    elsif @board[chan][0] > @board[chan][7]
      m.reply "#{@cl1}#{@player1[chan]}\003 #{Bold}wins!#{Bold}"
      @winner[chan] = 1
    else
      m.reply "#{@cl2}#{@player2[chan]}\003 #{Bold}wins!#{Bold}"
      @winner[chan] = 2
    end
    display(m, chan)
    update_stats(m, chan)
  end

end

p = KalahPlugin.new

['kalah', 'mancala'].each do |scope|
  p.map "#{scope} bot [:seeds]", :action => 'new_game',
    :defaults => { :bot_player => true, :seeds => 0 },
    :requirements => { :seeds => /^\d+$/ }
  p.map "#{scope} reset", :action => 'reset_everything',
    :auth_path => 'reset'
  p.map "#{scope} end", :action => 'stop',
    :auth_path => 'stop'
  p.map "#{scope} cancel", :action => 'stop',
    :auth_path => 'stop'
  p.map "#{scope} stop", :action => 'stop',
    :auth_path => 'stop'
  p.map "#{scope} stat[s] [:x]", :action => 'show_stats',
    :defaults => { :x => "x" }
  p.map "#{scope} score[s] [:x]", :action => 'show_stats',
    :defaults => { :x => "x" }
  p.map "#{scope} [:seeds]", :action => "new_game",
    :defaults => { :bot_player => false, :seeds => 0 },
    :requirements => { :seeds => /^\d+$/ }
end

p.default_auth('reset', false)
p.default_auth('stop', true)
