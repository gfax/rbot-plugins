#-- vim:sw=2:et
#++
#
# :title: sex
#
# Author:: gfax
# Copyright:: (C) 2012 gfax
# License:: GPL
# Version:: 2012-11-23

class SexPlugin < Plugin

  def help(plugin, topic)
    return "!sex - spouts silly, mad-lib-like, porn text. Optionally, you can specify names. " +
           "Usage: !sex [subject A] [Subject B]; Other commands: !gaysex !lesbosex"
  end

  def sexytime(m, params)
    # We'll take a random sample of the subjects later...
    # in case we have multiple males, females, or dongs.
    faster = [ "\"Let the games begin!\"", "\"Sweet Jesus!\"", "\"Not that!\"", "\"At last!\"",
               "\"Land o' Goshen!\"", "\"Is that all?\"", "\"Cheese it, the cops!\"",
               "\"I never dreamed it could be\"", "\"If I do, you won't respect me!\"", "\"Now!\"",
               "\"Open sesame!\"", "\"EMR!\"", "\"Again!\"", "\"Faster!\"", "\"Harder!\"", "\"Help!\"",
               "\"BOOM!!!, Headshot!\"", "\"Is it in yet?\"", "\"You aren't my father!\"",
               "\"Doctor, that's not *my* shoulder\"", "\"No, no, do the goldfish!\"",
               "\"Holy Batmobile, Batman!\"", "\"He's dead, he's dead!\"", "\"Take me, Robert!\"",
               "\"I'm a Republican!\"", "\"Put four fingers in!\"", "\"What a lover!\"",
               "\"Talk dirty, you pig!\"", "\"The ceiling needs painting,\"", "\"Suck harder!\"",
               "\"The animals will hear!\"", "\"Not in public!\"" ].sample
    said = [ "bellowed", "yelped", "croaked", "growled", "panted", "moaned", "grunted", "laughed",
             "warbled", "sighed", "ejaculated", "choked", "stammered", "wheezed", "squealed",
             "whimpered", "salivated", "tongued", "cried", "screamed", "yelled", "said" ].sample
    the = "the"
    fadj = [ "saucy", "wanton", "unfortunate", "lust-crazed", "nine-year-old", "bull-dyke", "bisexual",
             "gorgeous", "sweet", "nymphomaniacal", "large-hipped", "freckled", "forty-five year old",
             "white-haired", "large-boned", "saintly", "blind", "bearded", "blue-eyed", "large tongued",
             "friendly", "piano playing", "ear licking", "doe eyed", "sock sniffing", "lesbian", "hairy" ]
    female = [ "baggage", "hussy", "woman", "Duchess", "female impersonator", "nymphomaniac", "virgin",
               "leather freak", "home-coming queen", "defrocked nun", "bisexual budgie", "cheerleader",
               "office secretary", "sexual deviate", "DARPA contract monitor", "little matchgirl",
               "ceremonial penguin", "femme fatale", "bosses' daughter", "construction worker",
               "sausage abuser", "secretary", "Congressman's page", "grandmother", "penguin",
               "German shepherd", "stewardess", "waitress", "prostitute", "computer science group",
               "housewife", "lady of the evening", "semen collector", "aviatrix", "burn victm" ]
    as = "as"
    madj = [ "thrashing", "slurping", "insatiable", "rabid", "satanic", "corpulent", "nose-grooming",
               "tripe-fondling", "dribbling", "spread-eagled", "orally fixated", "vile",
               "awesomely endowed", "handsome", "mush-brained", "tremendously hung", "three-legged",
               "pile-driving", "cross-dressing", "gerbil buggering", "bung-hole stuffing",
               "sphincter licking", "hair-pie chewing", "muff-diving", "clam shucking", "egg-sucking",
               "bicycle seat sniffing" ]
    male = [ "rakehell", "hunchback", "lecherous lickspittle", "archduke", "midget", "hired hand",
             "great Dane", "stallion", "donkey", "electric eel", "paraplegic pothead",
             "dirty old man", "faggot butler", "friar", "black-power advocate", "follicle fetishist",
             "handsome priest", "chicken flicker", "homosexual flamingo", "ex-celibate", "drug sucker",
             "ex-woman", "construction worker", "hair dresser", "dentist", "judge",
              "social worker" ]
    diddled = [ "diddled", "devoured", "fondled", "mouthed", "tongued", "lashed", "tweaked", "violated",
                "defiled", "irrigated", "soiled", "ravished", "hammered", "bit", "tongue slashed",
                "sucked", "rubbed", "masturbated with", "slurped" ].sample
    titadj = [ "alabaster", "pink-tipped", "creamy", "rosebud", "moist", "throbbing", "juicy", "heaving",
               "straining", "mammoth", "succulent", "quivering", "rosey", "globular", "varicose",
               "jiggling", "bloody", "tilted", "dribbling", "oozing", "firm", "pendulous", "muscular",
               "bovine" ].sample
    knockers = [ "globes", "melons", "mounds", "buds", "paps", "chubbies", "protuberances", "treasures",
                 "buns", "bung", "vestibule", "armpits", "tits", "knockers", "elbows", "eyes", "hooters",
                 "jugs", "lungs", "headlights", "disk drives", "bumpers", "knees", "fried eggs",
                 "buttocks", "charlies", "ear lobes", "bazooms", "mammaries" ].sample
    _and = [ "and", "and then", "an'" ].sample
    thrust = [ "plunged", "thrust", "squeezed", "pounded", "drove", "eased", "slid", "hammered",
               "squished", "crammed", "slammed", "reamed", "rammed", "dipped", "inserted", "plugged",
               "augured", "pushed", "ripped", "forced", "wrenched" ].sample
    dongadj = [ "bursting", "jutting", "glistening", "Brobdingnagian", "prodigious", "purple", "searing",
                "swollen", "rigid", "rampaging", "warty", "steaming", "gorged", "trunklike",
                "foaming", "spouting", "swinish", "prosthetic", "blue veined", "engorged",
                "horse like", "throbbing", "humongous", "hole splitting", "serpentine", "curved",
                "steel encased", "glass encrusted", "knobby", "surgically altered", "metal tipped",
                "open sored", "rapidly dwindling", "swelling", "miniscule", "boney" ]
    dong = [ "intruder", "prong", "stump", "member", "meat loaf", "majesty", "bowsprit", "earthmover",
             "jackhammer", "ramrod", "cod", "jabber", "gusher", "poker", "engine", "brownie",
             "joy stick", "plunger", "piston", "tool", "manhood", "lollipop", "kidney prodder",
             "candlestick", "John Thomas", "arm", "testicles", "balls", "finger", "foot", "tongue",
             "dick", "one-eyed wonder worm", "canyon yodeler", "middle leg", "neck wrapper",
             "stick shift", "dong", "Linda Lovelace choker" ]
    into = [ "into", "right in", "inside" ].sample
    twatadj = [ "pulsing", "hungry", "hymeneal", "palpitating", "gaping", "slavering", "welcoming",
                "glutted", "gobbling", "cobwebby", "ravenous", "slurping", "glistening", "dripping",
                "scabiferous", "porous", "soft-spoken", "pink", "dusty", "tight", "odiferous", "moist",
                "loose", "scarred", "weaponless", "banana-stuffed", "tire-tracked", "mouse-nibbled",
                "tightly-tensed", "oft-traveled", "grateful", "festering" ].sample
    twat = [ "swamp", "honeypot", "jam jar", "butterbox", "furburger", "cherry pie", "cush", "slot",
             "slit", "cockpit", "damp", "furrow", "sanctum sanctorum", "bearded clam",
             "continental divide", "paradise valley", "red river valley", "slot machine", "quim",
             "palace", "areola", "rose bud", "throat", "eye socket", "tenderness", "inner ear",
             "orifice", "appendix scar", "wound", "navel", "mouth", "nose", "cunny" ].sample
    if params[:orientation] == 0
      subject1 = unless params[:name1].nil?
                   params[:name1]
                 else
                   "#{the} #{madj.sample} #{male.sample}"
                 end
      pronoun1 = "his"
      unless params[:name2].nil?
        subject2 = params[:name2]
        pronoun2 = "#{params[:name2]}'s"
      else
        subject2 = "#{the} #{fadj.sample} #{female.sample}"
        pronoun2 = "her"
      end
      m.reply "#{faster} #{said} #{subject2} #{as} #{subject1} #{diddled} #{pronoun2} " +
              "#{titadj} #{knockers} #{_and} #{thrust} #{pronoun1} #{dongadj.sample} " +
              "#{dong.sample} #{into} #{pronoun2} #{twatadj} #{twat}."
    elsif params[:orientation] == 1
      subject1 = unless params[:name1].nil?
                   params[:name1]
                 else
                   "#{the} #{madj.sample} #{male.sample}"
                 end
      pronoun1 = "his"
      unless params[:name2].nil?
        subject2 = params[:name2]
        pronoun2 = "#{params[:name2]}'s"
      else
        subject2 = "#{the} #{madj.sample} #{male.sample}"
        pronoun2 = "his"
      end
      m.reply "#{faster} #{said} #{subject2} #{as} #{subject1} #{diddled} #{pronoun2} " +
              "#{dongadj.sample} #{dong.sample} #{_and} #{thrust} #{pronoun1} #{dongadj.sample} " +
              "#{dong.sample} #{into} #{pronoun2} #{twatadj} #{twat}."
    else
      subject1 = unless params[:name1].nil?
                   params[:name1]
                 else
                   "#{the} #{fadj.sample} #{female.sample}"
                 end
      pronoun1 = "a"
      unless params[:name2].nil?
        subject2 = params[:name2]
        pronoun2 = "#{params[:name2]}'s"
      else
        subject2 = "#{the} #{fadj.sample} #{female.sample}"
        pronoun2 = "her"
      end
      m.reply "#{faster} #{said} #{subject2} #{as} #{subject1} #{diddled} #{pronoun2} " +
              "#{titadj} #{knockers} #{_and} #{thrust} #{pronoun1} #{dongadj.sample} " +
              "#{dong.sample} #{into} #{pronoun2} #{twatadj} #{twat}."
    end

  end

end


plugin = SexPlugin.new
plugin.map "sex [:name1 [:name2]]", :action => 'sexytime',
  :defaults => { :orientation => 0 }
plugin.map "gaysex [:name1 [:name2]]", :action => 'sexytime',
  :defaults => { :orientation => 1 }
plugin.map "lesbosex [:name1 [:name2]]", :action => 'sexytime',
  :defaults => { :orientation => 2 }
