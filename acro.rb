# Author:: David Gadling <dave@toasterwaffles.com>
# Author:: Jay Thomas <degradinglight@gmail.com>
# Copyright:: (C) 2008 David Gadling
# Copyright:: (C) 2012 Jay Thomas
# License:: BSD
# Version:: 2013-01-19
#
# Acrophobia - Submit backronyms and vote on the best! 
# http://en.wikipedia.org/wiki/Acrophobia_%28game%29
#
# TODO: Wow this plugin is very hackish. Definitely need to redo some things.
# FIXME: Fix stats and hall of fame.
# FIXME: Currently only works in one channel at a time since people /msg the
# bot with suggestions and votes. Any possible work-arounds?
# 

Hi = "\002\00312"
Clear = "\017"
MIN_ACRO_LENGTH = 3
MAX_ACRO_LENGTH = 5
SUB_TIME_DELTA = 5
BAD_LETTERS = Array['Q', 'X', 'V']
FORBIDDEN_LETTERS = Array['Z']
SPEED_POINTS = 2

class AcroPlugin < Plugin
  Config.register Config::IntegerValue.new('acro.rounds',
    :default => 5, :validate => Proc.new{|v| v > 0},
    :desc => "The default number of rounds of acro (if a number of rounds isn't specified at game start.)")
  Config.register Config::IntegerValue.new('acro.round_time',
    :default => 90, :validate => Proc.new{|v| v > 1},
    :desc => "Determines how much time users are allotted for submitting backronyms.")
  Config.register Config::IntegerValue.new('acro.vote_time',
    :default => 45, :validate => Proc.new{|v| v > 1},
    :desc => "Determines how much time users have to vote on acronyms.")

  def help(plugin, topic="")
    p = @bot.config['core.address_prefix'].first
    r = @bot.config['acro.rounds']
    case topic.downcase
    when 'hof'
      "hof [wins|points|submissions] => view the hall of fame " +
      "based on any of the keys mentioned. Default is wins."
    when 'play'
      "/msg #{@bot.nick} acro <your acronym> => " +
      "submit an expansion on the given acronym"
    when 'stop'
      "stop => stop playing acro"
    when 'stats'
      "stats => shows the total number of wins and points for a given player"
    when 'vote'
      "vote <number> => submit your vote for the best acronym"
    else
      "Acro, the rbot acrophobia game. #{p}#{plugin} start <# of rounds> " +
      "starts a game of acro; The default number of rounds is #{r}. -- " +
      "other help topics: hof, play, stats, stop, vote"
    end
  end

  def initialize()
    super
    @acro = ''
    @answers = Hash.new
    @ballot = Array.new
    @channel = ''
    @curr_timer = nil
    @len = 0
    @playing = false
    @rounds_left = 0
    @submit_order = Array.new
    @submitting = false
    @time = 0
    @voters = Array.new
    @voting = false
  end

  # Reset everything for a new round of the game
  def reset
    @acro = ''
    @answers.clear
    @ballot.clear
    @first_answerer = ''
    @len = 0
    @playing = true
    @submitting = false
    @submit_order.clear
    @time = 0
    @voters.clear
    @voting = false
  end

  def say(msg, opts={})
    @bot.say @channel, msg, opts
  end

  # Start a game by picking a new acronym and letting the rest take over
  def start(m, params)
    if @playing
      m.reply "I'm currently playing in #{@channel}. Come join us!"
      return
    end
    @playing = true
    @channel = m.channel
    @rounds_left = if params[:roundCount].to_i > 0
                    params[:roundCount].to_i 
                  else
                    @bot.config['acro.rounds']
                  end
    say "Starting #{Hi}#{@rounds_left}#{Clear} rounds of acrophobia..."
    pick_acronym()
  end

  # Starting a new round of a possibly new game. Pick an acronym and tell people
  # about it.
  def pick_acronym()
    if @rounds_left == 0 then stop(nil, nil) and return end
    reset
    @len = MIN_ACRO_LENGTH + rand(MAX_ACRO_LENGTH - MIN_ACRO_LENGTH)
    1.upto(@len) do |n|
      nextLetter = sprintf("%c", 65+rand(26))
      # 90% chance of picking a new letter if a bad letter was chosen
      if BAD_LETTERS.include?(nextLetter) and rand(101) > 10
        nextLetter = sprintf("%c", 65+rand(26)) 
      end
      @acro += nextLetter
    end
    @time = @bot.config['acro.round_time'] / 2

    @submitting = true
    say "The current acronym is: #{Hi}#{@acro}#{Clear} You have " +
        "#{Hi}#{@time*2}#{Clear} seconds to submit backronyms via " +
        "#{Hi}/msg #{@bot.nick} acro <my-version-of-the-acronym>#{Clear}"
    @curr_timer = @bot.timer.add_once(@time) {
        warning
    }
  end


  # Give everybody a warning about how much time they have left
  def warning
    say "#{Hi}#{@time}#{Clear} seconds left!"
    @curr_timer = @bot.timer.add_once(@time) {
      do_voting
    }
  end

  # Stop accepting submissions, tell people what 
  # they can vote on, and start accepting votes.
  def do_voting()
    @submitting = false
    say "Pencils down, time is up!"
    if @answers.keys.length < 2
      say "Not enough submissions, stopping."
      stop(nil, nil)
      return
    end
    say "Vote for one of the following and send it to " +
        "me via #{Hi}/msg #{@bot.nick} vote <Number>"
    @answers.each do |k,v| 
      @ballot.push({:candidate=>k, :votes=>0, :submitter=>v})
    end
    1.upto(@ballot.length) do |n|
      say "#{Hi}#{n}. #{@ballot[n-1][:candidate]}"
    end
    @voting = true
    say "You have #{Hi}#{@bot.config['acro.vote_time']} seconds to vote"
    @curr_timer = @bot.timer.add_once(@bot.config['acro.round_time']) { tally_votes }
  end

  # Tally up all the votes, assign points, and crown a winner
  def tally_votes()
    @voting = false
    say "Thanks for voting, let's look at the results!"

    # Score =
    # Number of votes + 
    # (First answer + less than 25 points = + 2 speed points)
    # (Most votes = + <Acronym length> bonus points)
    winner = ""
    winning_votes = 0
    @ballot.each do |n|
      user = @registry[n[:submitter]] || Hash.new
      user[:wins]        = user.fetch(:wins, 0)
      user[:submissions] = user.fetch(:submissions, 0) + 1
      user[:totalPoints] = user.fetch(:totalPoints, 0) + n[:votes]
      say "#{Hi}#{n[:submitter]}#{Clear}'s answer of " +
          "#{Hi}#{n[:candidate]}#{Clear} received " + 
          "#{Hi}#{n[:votes]}#{Clear} votes"
      if n[:votes] > winning_votes
        winner = n[:submitter]
        winning_votes = n[:votes]
      elsif n[:votes] == winning_votes
        winner = ""
      end
      if n[:submitter] == @submit_order[0]
        user[:totalPoints] = user.fetch(:totalPoints, 0) + SPEED_POINTS
        say "#{Hi}#{n[:submitter]}#{Clear} gets "+
            "#{Hi}#{SPEED_POINTS}#{Clear} speed points"
      end
        @registry[n[:submitter]] = user
    end

    if winner != ""
      our_winner = @registry[winner]
      our_winner[:totalPoints] = our_winner.fetch(:totalPoints, 0) + @len
      our_winner[:wins] = our_winner.fetch(:wins, 0) + 1
      say "#{Hi}#{winner}#{Clear} receives " +
          "#{Hi}#{@len}#{Clear} bonus points" +
          " for winning the round"
      @registry[winner] = our_winner
    end

    @rounds_left -= 1
    pick_acronym
  end

  # Figure out who the winnar is!
  def hof(m, params)
    fool = m.sourcenick
    tmp_key = params[:key].to_s
    if tmp_key == "points"
      tmp_key = "totalPoints"
    end
    target_key = tmp_key.to_sym
    m.reply "Checking out the #{params[:key].to_s} HoF..."
    tmp = @registry.to_hash
    sorted = tmp.sort { |a,b| b[1][target_key] <=> a[1][target_key] }

    winners_left = 5

    winners = []
    sorted.each do |player|
      winners << "#{player[0]} has #{player[1][target_key]}"
      winners_left -= 1
      break if winners_left == 0
    end
    m.reply(winners.join(" | "))
  end

  # Say we're done playing and kill any timers
  def stop(m, params)
    return if ! @playing
    say "Well that was fun."
    reset
    @playing = false
    @channel = ""
    @bot.timer.remove(@curr_timer)
  end

  # Make sure that we're playing a game AND accepting votes (errors otherwise).
  # Make sure the user hasn't already voted in this round
  # Record their vote
  def handle_vote(m, params)
    fool = m.sourcenick
    if !@playing
        @bot.notice(fool, "We're not playing acrophobia right now. Maybe you should start a game?")
      return
    end
    if !@voting
      @bot.notice(fool, "I'm not taking votes right now. Maybe you wanted to submit an answer?")
      return
    end

    vote = params[:input].to_s
    if vote !~ /^\d+$/
      @bot.notice(fool, "You need to vote for a #{Hi}number")
      return
    end

    if @voters.include?(m.sourcenick.to_s)
      @bot.notice(fool, "Too late. You already voted.")
      return
    end

    vote = vote.to_i
    if vote > @ballot.length or vote < 1
      @bot.notice(fool, "#{Hi}##{vote}#{Clear} wasn't an option!")
      return
    end

    @voters.push(m.sourcenick.to_s)
    @ballot[vote-1][:votes] += 1
    @bot.notice(fool, "Your vote for #{Hi}##{vote}#{Clear} " +
                      "(#{@ballot[vote-1][:candidate]}) has been recorded")
  end

  # Accept backronym submissions
  # Make sure they're the right length, and compress to the right acronym
  def handle_submission(m, params)
    fool = m.sourcenick
    if !@playing
      @bot.notice(fool, "We're not playing acrophobia right now. Maybe you should start a game?")
      return
    end
    if !@submitting
      @bot.notice(fool, "I'm not taking acronym submissions right now.Maybe you wanted to vote?")
      return
    end
    sender = m.sourcenick.to_s

    # First get all the cases where they can't submit or we can't accept their
    # answer for various reasons:
    # 1) It's the wrong length (too short or too long)
    # 2) It doesn't compress to the acronym we're looking for
    # 3) Somebody else already submitted it!
    # 4) They submitted the acronym, but spaced out
    submission = params[:input].to_s
    pieces = submission.gsub(/\s\[[a-zA-Z]{1,3}\]\s/, ' ').split(' ')
    whine = "I can't accept #{Hi}#{submission}#{Clear}"
    err = ""
    err = "long"  if pieces.length() > @len
    err = "short" if pieces.length() < @len

    if err != ""
      @bot.notice(fool, "#{whine}, it's too #{err}. " +
      "Try something #{Hi}#{@len}#{Clear} words long.")
      return
    end

    # For each piece of what they submitted, take the first character and make
    # it uppercase, appending it to the acronym version of what they submitted
    submittedAcronym = ""
    pieces.each { |chunk| submittedAcronym += chunk.split('')[0].upcase }

    # If what they submitted doesn't compresses to the acronym we're looking
    # for, tell them as much
    if submittedAcronym != @acro
        @bot.notice(fool, "#{whine}, it doesn't match the target acronym " +
                          "(#{Hi}#{@acro}#{Clear})")
      return
    end

    if @answers.has_key?(submission)
      @bot.notice(fool, "#{whine}, somebody already submitted it!")
      return
    end

    if submission.gsub(/\s/, '').upcase == @acro
      @bot.notice(fool, "#{whine}, you submitted the acronym itself!")
      return
    end

    # If they've submitted before, they lose their speed bonus and their old
    # answer goes away
    if @submit_order.include?(sender)
      @submit_order.delete(sender)
      @answers.delete(@answers.index(sender))
    end

    @submit_order.push(sender)
    @answers[submission] = sender
    if @first_answerer == ""
      @first_answerer = sender
    end
    @bot.notice(fool, "Your submission (#{Hi}#{submission}#{Clear}) has been accepted.")
    say "#{@answers.keys.length} submissions accepted."
  end

  # Generic processing of private messages
  # If we're not playing, suggest they start a game
  # If we're taking submissions, route appropriately
  # If we're voting, route appropriately
  def process_private(m, params)
    if ! @playing
      @bot.notice(fool, "We're not playing acrophobia right now. Maybe you should start a game?")
      return
    end

    handle_vote(m, params) if @voting
    handle_submission(m, params) if @submitting
  end

  # Simple processing of public messages. If we're playing or voting, tell them
  # it's secret. If we're not doing either of those, don't respond.
  def process_public(m, params)
    if @playing
      if @voting
        m.reply "I'm only listening for votes via /msg right now!"
       else
        m.reply "I'm only listening for submissions via /msg right now!"
      end
    end
  end

  # Show my stats to everybody. Yay e-penis!
  def show_stats(m, params)
    user = if params[:user].nil or params[:user].empty?
      m.sourcenick
    else
      params[:user]
    end
    foo = @registry[user.downcase]
    if foo == nil
      m.reply "You don't appear to have played acrophobia before!"
    else
      our_reply = "Submissions: #{Hi}#{foo[:submissions]}#{Clear}" +
                 " | Wins: #{Hi}#{foo[:wins]}#{Clear}" +
                 " | Points: #{Hi}#{foo[:totalPoints]}#{Clear}"
      if m.channel
        our_reply = "#{m.sourcenick.to_s}: #{our_reply}"
        m.reply our_reply
      else
        @bot.reply(m.sourcenick, our_reply)
      end
    end
  end

  # Stop the game if we get told to cleanup
  def cleanup()
    stop(nil, nil)
  end

end

# The wildcarded routes need to go last so that more
# specific commands, (e.g. hof,) get matched first.
plugin = AcroPlugin.new
plugin.map 'acro start [:roundCount]',
  :action => 'start', :private => false
plugin.map 'acro stop',
  :action => 'stop', :private => false
plugin.map 'acro stats [:user]',
  :action => 'show_stats'
plugin.map 'acro hof :key',
  :action => 'hof', :defaults => {:key => "wins"},
  :requirements => {:key => /^(?:wins|points|submissions)$/}
plugin.map 'vote *input',
  :action => 'handle_vote', :public => false
plugin.map 'acro *input',
  :action => 'process_private', :public => false
plugin.map 'acro *input',  
  :action => 'process_public', :private => false
