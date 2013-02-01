#-- vim:sw=2:et
#++
#
# Author:: Lite <degradinglight@gmail.com>
# Copyright:: (C) 2012 gfax.ch
# License:: GPL
#

class CrapPlugin < Plugin

  def help(plugin, topic="")
    "NO U"
  end

  def chat(m)
    if m.public?
      m.channel.name.downcase
      else m.sourcenick.downcase
      end
  end

  def message(m)
    return unless chat(m) == "#gfax" or chat(m) == "#botfax"
    b = @bot.nick.downcase
    case m.message.downcase
    ### BATMAN ###
    when /batman/
      case rand(19)
      when 1
        batman_quote = [ "The Batmobile is black because Batman couldn't get it in a darker color.",
                         "Batman was happier in the sixties. There may have been drugs involved.",
                         "If Batman were a candy, his flavor would be DARK.",
                         "Batman knows what you did.",
                         "#{Bold}Batman#{Bold}: \"Robin, England has no king now. England has a queen, " +
                           "and a great lady she is, too.\"",
                         "#{Bold}Robin#{Bold}: \"Gosh, Batman, this camel grass juice is great.\"" +
                           "#{Bold}Batman#{Bold}: \"Beware of strong stimulants, Robin.\"",
                         "#{Bold}Robin#{Bold}: \"Venus seemed like a nice girl in that costume.\" " +
                           "#{Bold}Batman#{Bold}: \"I suspect she is a nice girl down deep, but " +
                           "she's fallen in with bad companions. And who knows what her home " +
                           "life was like.\"",
                         "#{Bold}Batman#{Bold}: \"Go back outside and calm the flower children.\" " +
                           "#{Bold}Robin#{Bold}: \"They'll mob me\" #{Bold}Batman#{Bold}: \"Groovy.\"",
                         "#{Bold}Robin#{Bold}: \"Holy molars! Am I ever glad I take good care of " +
                           "my teeth!\" #{Bold}Batman#{Bold}: \"True. You owe your life to " +
                           "dental hygiene.\"",
                         "#{Bold}Miss Kitka#{Bold}: \"When I close my eyes, I imagine a world at " +
                           "peace.\" #{Bold}Bruce#{Bold}: \"That's strange... when I close my " +
                           "eyes, I imagine something quite astonishingly different.\"",
                         "#{Bold}Bruce#{Bold}: \"He's from Philadelphia.\" #{Bold}Dick#{Bold}: " +
                           "\"How did you know?\" #{Bold}Bruce#{Bold}: \"You dipped your " +
                           "dipthong. People from Philadelphia are known for that.\"",
                         "#{Bold}Dick#{Bold} (reading in library): \"Gosh, Bruce. That Genghis " +
                           "Khan was quite a guy.\"",
                         "#{Bold}Commissioner Gordon#{Bold}: \"Batman, you unscrambled that " +
                           "safe's combination in three seconds flat! How did you do it?\" " +
                           "#{Bold}Batman#{Bold}: \"With my Three-Seconds-Flat-Bat-" +
                           "Combination-Unscrambler, Commissioner.\"",
                         "#{Bold}Robin#{Bold}: \"You can't get away from Batman that easy!\" " +
                           "#{Bold}Batman#{Bold}: \"Easily.\" #{Bold}Robin#{Bold}: \"Easily.\"" +
                           "#{Bold}Batman#{Bold}: \"Good grammar is essential, Robin.\" " +
                           "#{Bold}Robin#{Bold}: \"Thank you.\" #{Bold}Batman#{Bold}: \"You're " +
                           "welcome.\"",
                         "#{Bold}Robin#{Bold}: \"Grimalkin? What kind of a name is that?\" " +
                           "#{Bold}Batman#{Bold}: \"An obscure but nevertheless acceptable " +
                           "synonym for cat, Robin.\"",
                         "#{Bold}Robin#{Bold}: \"Where'd you get a live fish, Batman?\" " +
                           "#{Bold}Batman#{Bold}: \"The true crimefighter always carries " +
                           "everything he needs in his utility belt, Robin.\"",
                         "#{Bold}Robin#{Bold}: \"Picked up the seal pulsator yet, Batman?\" " +
                           "#{Bold}Batman#{Bold}: \"We're still over land, Robin, and a seal " +
                           "is an aquatic, marine mammal.\" #{Bold}Robin#{Bold}: \"Gosh, yes, " +
                           "Batman, I forgot.\"",
                         "#{Bold}Puzzler#{Bold}: \"When you reach 20,000 feet, an automatic " +
                           "mechanism will release the basket from the balloon, and you both " +
                           "will reaffirm Newton's law of universal gravitation - back down " +
                           "20,000 feet!\" #{Bold}Robin#{Bold}: \"I'll bet even Shakespeare " +
                           "didn't have words for such villainy!\"",
                         "#{Bold}Batman#{Bold}: \"The joke's on you, Riddler!\" " +
                           "#{Bold}Robin#{Bold}: \"When is a donkey spelled with 1 letter?! " +
                           "When it's #{Underline}U#{Underline}.\"",
                         "#{Bold}King Tut#{Bold} (upon regaining consciousness): \"What is this?\" " +
                           "#{Bold}Batman#{Bold}: \"America... simply America.\"" ]
        m.reply batman_quote.sample
      end
    ### HIGGINS VON HIGGINS ###
    when /your incredible journey ends today/
      m.reply "I don't think so, Corporal Tyranus."
    when /i don'?t think so,? corporal tyranus/
      m.reply "Let's finish this."
    when /let'?s finish this/
      m.reply "You're mine!"
    when /you'?re mine!/
      @bot.kick(m.replyto, m.sourcenick, "*EXPLODES YOU WITH A GUITAR SOLO*") if m.public?
    ### RETORTS ###
    when /^\[\;/
      m.reply "\;\["
    when /^anybody wan/i, /^anyone wan/
      m.reply "DON'T DO IT, IT'S A TRAP"
    when /^fu ?#{b}\b/
      m.reply "FU #{m.sourcenick.upcase}"
    when /fu man/
      m.reply "fu manchu"
    when /hello,? #{b}/
      m.reply "Wow... no homo, #{m.sourcenick}."
    when /^hello (th|d)ere(.|!)?$/
      m.reply "Oh no. It's you."
    when /^hello (th|d)ere,? #{b}/
      m.reply "Oh no. It's #{m.sourcenick}."
    when /^no #{b}\b/
      if m.sourcenick.downcase == "oddbondboris"
        m.reply "no roach"
      else
        m.reply "NO OBB"
      end
    when /no u/
      if rand(500) == 0
        m.reply "OK FINE, ME"
      else
        m.reply "NO U"
      end
    when /^oh u/
      m.reply "oh YES"
    when /^oh hai,? #{b}/
      m.reply "oh hai #{m.sourcenick}"
    when /^pingas/
      m.reply "pongas"
    when /^um$/
      m.reply "UM U"
    when "yo #{b}"
      m.reply "yo #{m.sourcenick}"
    end
  end

end

plugin = CrapPlugin.new
