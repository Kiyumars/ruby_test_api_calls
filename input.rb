require 'json'
require 'uri'

require 'net/http'

TMDB_key = ENV['tmdb_key']
puts "Enter actor."
actor_parameter = "&query=matt+damon"
# actor_query = gets.chomp.downcase
# actor_name = actor_query.split(" ")
# actor_parameter = "&query=" + actor_name[0] + "+" + actor_name[-1]
# puts actor_parameter

def request_json(request_type_url, extra_url='')
	request_url = "http://api.themoviedb.org/3/"
	request_url += request_type_url
	request_url += "?api_key="
	request_url += TMDB_key
	request_url += extra_url

	resp = Net::HTTP.get_response(URI(request_url))
	return JSON(resp.body)
end


def prepare_movie_hash(movie_id)
	movie_hash = Hash.new
	basic_movie_keys = ['id', 'title', 'overview', 'release_date',
						 'tagline']
	basic_info = request_json("movie/" + movie_id.to_s)

	basic_movie_keys.each do |basic_key|
		movie_hash[basic_key] = basic_info[basic_key]	
	end
	if basic_info['poster_path'] != nil
		movie_hash['poster_path'] = "http://image.tmdb.org/t/p/w500" + basic_info['poster_path']
	end

	casts_request = request_json("movie/" + movie_id.to_s + "/casts")
	cast_list = Array.new
	casts_request['cast'].each do |actor|
		if actor['order'] < 5 then
			cast_list.push(actor['name'])
		end
	end
	movie_hash['cast'] = cast_list.join(", ")
	
	directors = Array.new 
	screenwriters = Array.new
	casts_request['crew'].each do |crew|
		if crew['job'] == "Director" then
			directors.push(crew['name'])
		elsif crew['job'] == "Screenplay" then
			screenwriters.push(crew['name'])
		end
	end
	if directors.length > 0 then
		movie_hash['director'] = directors.join(", ")
	end
	if screenwriters.length > 0 then
		movie_hash['screenwriter'] = screenwriters. join(", ")
	end

	trailer_json = request_json("movie/" + movie_id.to_s + "/videos")
	if trailer_json['results'].length > 0
		trailer_url = "https://www.youtube.com/watch?v=" + trailer_json['results'][0]['key']
		movie_hash['trailer'] = trailer_url
	end

	puts movie_hash
	# return movie_hash

end

search_actor = request_json("search/person", actor_parameter)
actor_id = search_actor['results'][0]['id'].to_s
actor_filmography_request_url = "person/" + actor_id + "/movie_credits"
actor_filmography = request_json(actor_filmography_request_url)

movie_ids_list = Array.new
actor_filmography['cast'].each do |movie_dict|
	movie_ids_list.push(movie_dict['id'])
end

movie_ids_list.each do |movie_id|
	puts prepare_movie_hash(movie_id)
	# movie_url = "movie/" + movie_id.to_s
	# movie_dict = request_json(movie_url)
	# puts movie_dict['title']
	# puts movie_dict['overview']
	# puts movie_dict['tagline']
end

# request_url = "http://api.themoviedb.org/3/search/person?api_key="
# request_url += tmdb_key
# request_url += "&query="
# request_url += actor_name[0] + "+" + actor_name[1]

# resp = Net::HTTP.get_response(URI(request_url))
# resp_json = JSON(resp.body)

# actor_id = resp_json['results'][0]['id']
# films_request = "http://api.themoviedb.org/3/person/"
# films_request += actor_id.to_s
# films_request += "/movie_credits?api_key="
# films_request += tmdb_key
# films_resp = Net::HTTP.get_response(URI(films_request))
# films_json = JSON(films_resp.body)

# movie_ids = Array.new
# films_json['cast'].each do | movie_dict |
# 	movie_ids.push(movie_dict['id'])
# end

# movie_titles = Array.new
# movie_ids.each do | movie_id |
# 	movie_request_url = "http://api.themoviedb.org/3/movie/"
# 	movie_request_url += movie_id.to_s
# 	movie_request_url += "?api_key="
# 	movie_request_url += tmdb_key

# 	movie_resp = Net::HTTP.get_response(URI(movie_request_url))
# 	movies_json = JSON(movie_resp.body)
# 	begin
# 		movie_titles.push("http://image.tmdb.org/t/p/w500" + movies_json['poster_path'])
# 		puts "http://image.tmdb.org/t/p/w500" + movies_json['poster_path']
# 	rescue TypeError
# 		puts "TypeError"
# 		next
# 	end
# end

# puts movie_titles