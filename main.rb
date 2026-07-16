require "httparty"
require "pp"
require "nokolexbor"
require 'json'

# base_url = "https://games-stats.com/steam/game/fortune-paradox/"
BASE_URL = "https://store.steampowered.com/app/" # 4906570
# response = HTTParty.get BASE_URL#, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:152.0) Gecko/20100101 Firefox/152.0'}
# $document = Nokolexbor.HTML response
Game = Struct.new :url, :title, :media, :description, :reviews, :release, :price, :demo, :publishers, :developers, :early_access, :followers, :tags, :features
Reviews = Struct.new :value, :percent, :count, :rating, :best, :worst
Money = Struct.new :price, :currency, :revenue, :sale_price, :sale_percent
Media = Struct.new :capsule, :screenshots
$games = []
# puts $document

def text_at(css)
	element = $document.at_css(css)
	return nil if element.nil? # Not released yet
	element.text.strip
end

def money_at(css)
  text = text_at css
  return nil if text.nil?
  text[/\d+\.\d+/]
end

def percent_at(css)
  text = text_at css
  return nil if text.nil?
  text[/(\d+)/]
end

def attribute_at(css, attribute)
	$document.at_css(css).attribute(attribute).value
end

# These numbers are from https://profitable.app/tools/steam-revenue-calculator
def revenue_from(review_count, price)
	boxleiter_coefficient = 30 # Usually 20-100, depending on the game. 30 is a good generic number.
	gross = review_count.to_f * boxleiter_coefficient * price.to_f
	regional_adjustment = 0.85
	refunds = 0.91
	steam_cut = 0.7 # This can actually go up to a 0.8 share if you make a lot of money from it. Probably you won't.
	vat = 0.92
	gross * regional_adjustment * refunds * steam_cut * vat
end

def screenshots_from(css)
  data = $document.at_css(css).attribute("data-props").value
  # In order to extract video files we would need to grab the m3u8 or mpd files,
  # grab the m4s files from there, cat them together into one mp4 file. Not really
  # worth it, imo.
  # See: https://fileinfo.com/extension/m4s
  JSON.parse(data)["screenshots"].map { |screenshot| screenshot["full"] }
end

def reviews_from(css)
  value = text_at(css + " .game_review_summary")
  percent = percent_at(css + " .responsive_reviewdesc")
  count = attribute_at(css + " meta[itemprop='reviewCount']", 'content')
  rating = attribute_at(css + " meta[itemprop='ratingValue']", 'content')
  best = attribute_at(css + " meta[itemprop='bestRating']", 'content')
  worst = attribute_at(css + " meta[itemprop='worstRating']", 'content')
  Reviews.new value, percent, count, rating, best, worst
end

def money_from(css, reviews_count)
  price = money_at(css + " .game_purchase_price")
  if price.nil?
    price = money_at(css + " .discount_original_price")
    sale_price = money_at(css + " .discount_final_price")
    sale_percent = percent_at(css + " .discount_pct")
  else
    sale_price = nil
    sale_percent = nil
  end
  revenue = price.nil? ? nil : revenue_from(reviews_count, price)
  # TODO: We can grab the currency ("CAD") without hardcoding it in
  Money.new price, "CAD", revenue, sale_price, sale_percent
end

def media_from_globals
  capsule = attribute_at("#gameHeaderImageCtn img", 'src')
  screenshots = screenshots_from ".gamehighlight_desktopcarousel"
  Media.new capsule, screenshots
end

def text_array_at(css, index, entry)
  section = $document.css(css)[index]
  section.css(entry).map do |entry|
    entry.text.strip
  end
end

def css_exists(css)
  not $document.at_css(css).nil?
end

def followers_for(title_of_game)
  # https://newsletter.gamediscover.co/p/steams-follower-counts-hidden-in
  # use this to implement https://steamcommunity.com/search/groups/#text=deltarune
  # This can be useful because week 1 sales might be estimated with followers * 2.5
  nil
end

ARGV.each do |game_id|
  puts "Scraping for #{game_id}"
  url = BASE_URL + game_id
  response = HTTParty.get url#, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:152.0) Gecko/20100101 Firefox/152.0'}
  $document = Nokolexbor.HTML response

  title = text_at("#appHubAppName")
  description = text_at(".game_description_snippet")
  release = text_at(".release_date")[/\t+(.+)/, 1]
  demo = css_exists(".demo_above_purchase")
  developers = text_array_at(".dev_row .summary", 0, 'a')
  publishers = text_array_at(".dev_row .summary", 1, 'a')
  early_access = css_exists("#earlyAccessHeader")
  followers = followers_for "title_of_game"
  tags = text_array_at(".popular_tags", 0, "a.app_tag")
  # platforms = text_array_at(".sysreq_tabs", 0, ".sysreq_tab")
  features = text_array_at(".game_area_features_list_ctn", 0, "div.label")

  reviews = reviews_from "#userReviews"
  money = money_from ".game_area_purchase_game_wrapper", reviews.count
  media = media_from_globals

  game = Game.new url, title, media, description, reviews, release, money, demo, publishers, developers, early_access, followers, tags, features
  $games << game
end

$games.each do |game|
  pp game.title
end

# vr = "VR" mentioned in features
# self_published = anything in developers is also in publishers
# platforms are annoying to fetch so we don't