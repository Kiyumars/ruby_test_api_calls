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

def get_basic_movie_info(movie_hash, movie_id)
	basic_movie_keys = ['id', 'title', 'overview', 'release_date',
						 'tagline']
	basic_info = request_json("movie/" + movie_id.to_s)

	basic_movie_keys.each do |basic_key|
		movie_hash[basic_key] = basic_info[basic_key]	
	end
	if basic_info['poster_path'] != nil
		movie_hash['poster_path'] = "http://image.tmdb.org/t/p/w500" + basic_info['poster_path']
	end
end


def get_five_topbilled_actors(casts_request, movie_hash)
	cast_list = Array.new
	casts_request['cast'].each do |actor|
		if actor['order'] < 5 then
			cast_list.push(actor['name'])
		end
	end
	movie_hash['cast'] = cast_list.join(", ")
end


def get_directors_and_screenwriters(casts_request, movie_hash)
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
end


def get_casts_info(movie_hash, movie_id)
	casts_request = request_json("movie/" + movie_id.to_s + "/casts")
	
	get_five_topbilled_actors(casts_request, movie_hash)	
	get_directors_and_screenwriters(casts_request, movie_hash)	
end


def get_videos(movie_hash, movie_id)
	videos_json = request_json("movie/" + movie_id.to_s + "/videos")
	if videos_json['results'].length > 0 then
		videos_json['results'].each do |video|
			if video['type'] == "Trailer" then
				movie_hash['trailer'] = "https://www.youtube.com/watch?v=" + video['key']
			elsif video['type'] == "Featurette" then
				movie_hash['featurette'] = "https://www.youtube.com/watch?v=" + video['key']
			end
		end
	end
end


def prepare_movie_hash(movie_id)
	movie_hash = Hash.new
	get_basic_movie_info(movie_hash, movie_id)
	get_casts_info(movie_hash, movie_id)
	get_videos(movie_hash, movie_id)
	
	puts movie_hash
end


def search_tmdb_for_actor_and_filmography(actor_parameter)
	search_actor = request_json("search/person", actor_parameter)
	actor_id = search_actor['results'][0]['id'].to_s
	actor_filmography_request_url = "person/" + actor_id + "/movie_credits"
	return request_json(actor_filmography_request_url)
end


actor_filmography = search_tmdb_for_actor_and_filmography(actor_parameter)
movie_ids_list = Array.new
actor_filmography['cast'].each do |movie_dict|
	movie_ids_list.push(movie_dict['id'])
end

movie_ids_list.each do |movie_id|
	puts prepare_movie_hash(movie_id)

end

