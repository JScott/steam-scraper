require "httparty"
require "pp"
require "nokolexbor"
require 'json'

# base_url = "https://games-stats.com/steam/game/fortune-paradox/"
base_url = "https://store.steampowered.com/app/1207650/" # 4906570
response = HTTParty.get base_url#, headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:152.0) Gecko/20100101 Firefox/152.0'}
$document = Nokolexbor.HTML response
Game = Struct.new :url, :title, :media, :description, :reviews, :release, :price, :demo
Reviews = Struct.new :value, :percent, :count, :rating, :best, :worst
Money = Struct.new :price, :currency, :revenue, :sale_price, :sale_percent
Media = Struct.new :capsule, :screenshots
games = []
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

def media_from(css)
  # images = $document.at_css(css).css("img")
  data = $document.at_css(css).attribute("data-props").value
  pp JSON.parse(data)["screenshots"].map { |screenshot| screenshot["full"] }
  JSON.parse(data)
  # In order to extract video files we would need to grab the m3u8 or mpd files,
  # grab the m4s files from there, cat them together into one mp4 file. Not really
  # worth it, imo.
  # See: https://fileinfo.com/extension/m4s
end

# pp response
# pp document
# do
  url = base_url
#   pp document.content
  title = text_at("#appHubAppName")
  description = text_at(".game_description_snippet")
  release = text_at(".release_date")[/\t+(.+)/, 1]
  demo = not $document.at_css(".demo_above_purchase").nil?
	
  value = text_at("#userReviews .game_review_summary")
  percent = percent_at("#userReviews .responsive_reviewdesc")
  count = attribute_at("#userReviews meta[itemprop='reviewCount']", 'content')
  rating = attribute_at("#userReviews meta[itemprop='ratingValue']", 'content')
  best = attribute_at("#userReviews meta[itemprop='bestRating']", 'content')
  worst = attribute_at("#userReviews meta[itemprop='worstRating']", 'content')
  reviews = Reviews.new value, percent, count, rating, best, worst


  price = money_at(".game_area_purchase_game_wrapper .game_purchase_price")
  if price.nil?
    price = money_at(".game_area_purchase_game_wrapper .discount_original_price")
    sale_price = money_at(".game_area_purchase_game_wrapper .discount_final_price")
    sale_percent = percent_at(".game_area_purchase_game_wrapper .discount_pct")
  else
    sale_price = nil
    sale_percent = nil
  end
  revenue = price.nil? ? nil : revenue_from(reviews.count, price)
  money = Money.new price, "CAD", revenue, sale_price, sale_percent

  capsule = attribute_at("#gameHeaderImageCtn img", 'src')
  media_data = media_from ".gamehighlight_desktopcarousel"
  screenshots = []
  videos = []
  media = Media.new capsule, screenshots

  game = Game.new url, title, media, description, reviews, release, money, demo
  pp game
# end
