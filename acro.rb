# Author:: David Gadling <dave@toasterwaffles.com>
# Author:: Lite <degradinglight@gmail.com>
# Copyright:: (C) 2008 David Gadling
# Copyright:: (C) 2012 Lite
# License:: BSD
# Version:: 2012-05-19
#
# Acrophobia - Submit backronyms and vote on the best! 
# http://en.wikipedia.org/wiki/Acrophobia_%28game%29
#
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
    case topic
    when 'hof'
      "hof [wins|points|submissions] => view the hall of fame based on any of the keys mentioned. Default is wins."
    when 'play'
      "/msg #{@bot.nick} acro <your acronym> => submit an expansion on the given acronym"
    when 'stop'
      "stop => stop playing acro"
    when 'stats'
      "stats => shows the total number of wins and points for a given player"
    when 'vote'
      "vote <number> => submit your vote for the best acronym"
    else
      "Acro, the rbot acrophobia game. !#{plugin} start <# of rounds> starts a game of acro; The default number of rounds is #{@bot.config['acro.rounds']}. -- other help topics: hof, play, stats, stop, vote"
    end
  end


  def initialize()
    super
    @answers = Hash.new
    @voters = Array.new
    @ballot = Array.new
    @submitOrder = Array.new
    @playing = false
    @submitting = false
    @voting = false
    @acro = ""
    @len = 0
    @channel = ""
    @currTimer = nil
    @time = 0
    @roundsLeft = 0
  end


  # Reset everything for a new round of the game
  def reset()
    @acro = ""
    @ballot.clear
    @answers.clear
    @voters.clear
    @submitOrder.clear
    @playing = true
    @voting = false
    @submitting = false
    @len = 0
    @firstAnswerer = ""
    @time = 0
  end


  # Start a game by picking a new acronym and letting the rest take over
  def startGame(m, params)
    if @playing
      m.reply("I'm currently playing in #{@channel}, come join us!")
      return
    end
    @playing = true
    @channel = m.channel
    @roundsLeft = if params[:roundCount].to_i > 0 then params[:roundCount].to_i else @bot.config['acro.rounds'] end
    @bot.say(@channel, "Starting #{Hi}#{@roundsLeft}#{Clear} rounds of acrophobia")
    pickNewAcronym()
  end


  # Starting a new round of a possibly new game. Pick an acronym and tell people
  # about it.
  def pickNewAcronym()
    if @roundsLeft == 0 then stopGame(nil, nil) and return end
    reset()
    @len = MIN_ACRO_LENGTH + rand(MAX_ACRO_LENGTH - MIN_ACRO_LENGTH)
    1.upto(@len) do |n|
      nextLetter = sprintf("%c", 65+rand(26))
      # 90% chance of picking a new letter if a bad letter was chosen
      if BAD_LETTERS.include?(nextLetter) and rand(101) > 10
        nextLetter = sprintf("%c", 65+rand(26)) 
        end
      @acro += nextLetter
      end

    # FIXME: Should we add time for longer acronyms? joe says "no".
    @time = @bot.config['acro.round_time'] / 2

    @submitting = true
    @bot.say(@channel, "The current acronym is: #{Hi}#{@acro}#{Clear}")
    @bot.say(@channel, "You have #{Hi}#{@time*2}#{Clear} seconds to submit backronyms" +
                       " via #{Hi}/msg #{@bot.nick} acro <my-version-of-the-acronym>#{Clear}")
    @currTimer = @bot.timer.add_once(@time) {
        warning
    }
  end


  # Give everybody a warning about how much time they have left
  def warning()
    @bot.say(@channel, "#{Hi}#{@time}#{Clear} seconds left!")
    @currTimer = @bot.timer.add_once(@time) {
      transitionToVoting
    }
  end


  # Stop accepting submissions, tell people what they can vote on, and start
  # accepting votes
  def transitionToVoting()
    @submitting = false
    @bot.say(@channel, "Pencils down, time is up!")
    if @answers.keys.length < 2
      @bot.say(@channel, "Not enough submissions, stopping.")
      stopGame(nil, nil)
      return
      end
    @bot.say(@channel, "Vote for one of the following and send it to " +
                       "me via #{Hi}/msg #{@bot.nick} vote <Number>")
    @answers.each { |k,v| 
      @ballot.push({:candidate=>k, :votes=>0, :submitter=>v})
      }
    1.upto(@ballot.length) { |n|
      @bot.say(@channel, "#{Hi}#{n}. #{@ballot[n-1][:candidate]}")
      }
    @voting = true
    @bot.say(@channel, "You have #{Hi}#{@bot.config['acro.vote_time']} seconds to vote")
    @currTimer = @bot.timer.add_once(@bot.config['acro.round_time']) { tallyVotes }
  end


  # Tally up all the votes, assign points, and crown a winner
  def tallyVotes()
    @voting = false
    @bot.say(@channel, "Thanks for voting, let's look at the results!")

    # Score =
    # Number of votes + 
    # (First answer + less than 25 points = + 2 speed points)
    # (Most votes = + <Acronym length> bonus points)
    winner = ""
    winningVotes = 0
    @ballot.each do |n|
      user = @registry[n[:submitter]] || Hash.new
      user[:wins]        = user.fetch(:wins, 0)
      user[:submissions] = user.fetch(:submissions, 0) + 1
      user[:totalPoints] = user.fetch(:totalPoints, 0) + n[:votes]
      @bot.say(@channel, "#{Hi}#{n[:submitter]}#{Clear}'s answer of " +
                         "#{Hi}#{n[:candidate]}#{Clear} received " + 
                         "#{Hi}#{n[:votes]}#{Clear} votes")
      if n[:votes] > winningVotes
        winner = n[:submitter]
        winningVotes = n[:votes]
        elsif n[:votes] == winningVotes
        winner = ""
        end
      if n[:submitter] == @submitOrder[0]
        user[:totalPoints] = user.fetch(:totalPoints, 0) + SPEED_POINTS
        @bot.say(@channel, "#{Hi}#{n[:submitter]}#{Clear} gets "+
                           "#{Hi}#{SPEED_POINTS}#{Clear} speed points")
        end
        @registry[n[:submitter]] = user
      end

    if winner != ""
      ourWinner = @registry[winner]
      ourWinner[:totalPoints] = ourWinner.fetch(:totalPoints, 0) + @len
      ourWinner[:wins] = ourWinner.fetch(:wins, 0) + 1
      @bot.say(@channel, "#{Hi}#{winner}#{Clear} receives " +
                         "#{Hi}#{@len}#{Clear} bonus points" +
                         " for winning the round")
      @registry[winner] = ourWinner
      end

    @roundsLeft = @roundsLeft - 1
    pickNewAcronym
  end


  # Figure out who the winnar is!
  def hof(m, params)
    fool = m.sourcenick
    tmpKey = params[:key].to_s
    if tmpKey == "points"
      tmpKey = "totalPoints"
      end
    targetKey = tmpKey.to_sym
    m.reply("Checking out the #{params[:key].to_s} HoF...")
    tmp = @registry.to_hash
    sorted = tmp.sort { |a,b| b[1][targetKey] <=> a[1][targetKey] }

    winnersLeft = 5

    winners = []
    sorted.each do |player|
      winners << "#{player[0]} has #{player[1][targetKey]}"
      winnersLeft -= 1
      if winnersLeft == 0
        break
        end
      end
    m.reply(winners.join(" | "))
  end


  # Say we're done playing and kill any timers
  def stopGame(m, params)
    return if ! @playing
    @bot.say(@channel, "Well that was fun.")
    reset()
    @playing = false
    @channel = ""
    @bot.timer.remove(@currTimer)
  end


  # Make sure that we're playing a game AND accepting votes (errors otherwise).
  # Make sure the user hasn't already voted in this round
  # Record their vote
  def handleVote(m, params)
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
  def handleSubmission(m, params)
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
    if @submitOrder.include?(sender)
      @submitOrder.delete(sender)
      @answers.delete(@answers.index(sender))
      end

    @submitOrder.push(sender)
    @answers[submission] = sender
    if @firstAnswerer == ""
      @firstAnswerer = sender
      end
    @bot.notice(fool, "Your submission (#{Hi}#{submission}#{Clear}) has been accepted")
    @bot.say(@channel, "#{@answers.keys.length} submissions accepted")
  end


  # Generic processing of private messages
  # If we're not playing, suggest they start a game
  # If we're taking submissions, route appropriately
  # If we're voting, route appropriately
  def processPrivate(m, params)
    if ! @playing
      @bot.notice(fool, "We're not playing acrophobia right now. Maybe you should start a game?")
      return
      end

    handleVote(m, params) if @voting
    handleSubmission(m, params) if @submitting
  end


  # Simple processing of public messages. If we're playing or voting, tell them
  # it's secret. If we're not doing either of those, don't respond.
  def processPublic(m, params)
    if @playing
      if @voting
        m.reply("I'm only listening for votes via /msg right now!")
       else
        m.reply("I'm only listening for submissions via /msg right now!")
        end
      end
  end


  # Show my stats to everybody. Yay e-penis!
  def showMyStats(m, params)
    user = if params[:user].nil or params[:user].empty?
      m.sourcenick
      else
      params[:user]
      end
    foo = @registry[user.downcase]
    if foo == nil
      m.reply "You don't appear to have played acrophobia before!"
      else
      ourReply = "Submissions: #{Hi}#{foo[:submissions]}#{Clear}" +
                 " | Wins: #{Hi}#{foo[:wins]}#{Clear}" +
                 " | Points: #{Hi}#{foo[:totalPoints]}#{Clear}"
      if m.channel
        ourReply = "#{m.sourcenick.to_s}: #{ourReply}"
        m.reply ourReply
        else
        @bot.reply(m.sourcenick, ourReply)
        end
      end
  end


  # Stop the game if we get told to cleanup
  def cleanup()
    stopGame(nil, nil)
  end

end

# The wildcarded routes need to go last so that more specific commands (e.g.
# hof) get matched first
plugin = AcroPlugin.new
plugin.map 'acro start [:roundCount]', :action => 'startGame',    :private => false
plugin.map 'acro stop',              :action => 'stopGame',       :private => false
plugin.map 'acro stats [:user]',     :action => 'showMyStats'
plugin.map 'acro hof :key',          :action => 'hof', :defaults => {:key => "wins"}, :requirements => {:key => /^(?:wins|points|submissions)$/}
plugin.map 'vote *input',            :action => 'handleVote',     :public => false
plugin.map 'acro *input',            :action => 'processPrivate', :public => false
plugin.map 'acro *input',            :action => 'processPublic',  :private => false
