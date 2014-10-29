require 'json'
require 'uri'

require 'net/http'

TMDB_key = ENV['tmdb_key']
RT_key = ENV['rt_key']


def request_tmdb_json(request_type_url, extra_url='')
	request_url = "http://api.themoviedb.org/3/"
	request_url += request_type_url
	request_url += "?api_key="
	request_url += TMDB_key
	request_url += extra_url

	resp = Net::HTTP.get_response(URI(request_url))
	return JSON(resp.body)
end


def get_basic_movie_info(movie_hash, movie_id)
	basic_movie_keys = ['id', "imdb_id", 'title', 'overview', 'release_date',
						 'tagline']
	basic_info = request_tmdb_json("movie/" + movie_id.to_s)

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
	casts_request = request_tmdb_json("movie/" + movie_id.to_s + "/casts")
	
	get_five_topbilled_actors(casts_request, movie_hash)	
	get_directors_and_screenwriters(casts_request, movie_hash)	
end


def get_videos(movie_hash, movie_id)
	videos_json = request_tmdb_json("movie/" + movie_id.to_s + "/videos")
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
	enough_movie_reviews = add_rt_info(movie_hash['imdb_id'][2..-1], movie_hash)
	if ! enough_movie_reviews then
		return nil
	end
	critics_score, audience_score = enough_movie_reviews
	movie_hash['critics_score'] = critics_score
	movie_hash['audience_score'] = audience_score
	get_casts_info(movie_hash, movie_id)
	get_videos(movie_hash, movie_id)
	
	puts movie_hash
end


def search_tmdb_for_actor_and_filmography(actor_parameter)
	search_actor = request_tmdb_json("search/person", actor_parameter)
	actor_id = search_actor['results'][0]['id'].to_s
	actor_filmography_request_url = "person/" + actor_id + "/movie_credits"
	return request_tmdb_json(actor_filmography_request_url)
end


def get_json_from_rt_movie_alias(imdb_movie_id)
	request_url = "http://api.rottentomatoes.com/api/public/v1.0/"
	request_url += "movie_alias.json?apikey=" + RT_key
	request_url += "&type=imdb&id=" + imdb_movie_id

	resp = Net::HTTP.get_response(URI(request_url))
	return JSON(resp.body)
end 


def check_if_rt_scores_exist_and_return(imdb_movie_id)
	rt_json = get_json_from_rt_movie_alias(imdb_movie_id)
	begin
		critics_score = rt_json['ratings']['critics_score']
	rescue NoMethodError
		puts "No method error"
		puts imdb_movie_id
		return false
	end
	if critics_score < 0 or critics_score == nil then
		puts "No reviews"
		puts imdb_movie_id
		return false
	end
	audience_score = rt_json['ratings']['audience_score']
	rt_movie_id = rt_json['id']
	return critics_score, audience_score, rt_movie_id
end


def check_if_six_reviews_exist(rt_movie_id)
	request_url = "http://api.rottentomatoes.com/api/public/v1.0/movies/"
	request_url += rt_movie_id.to_s + "/reviews.json?"
	request_url += "apikey=" + RT_key

	resp = Net::HTTP.get_response(URI(request_url))
	total_reviews = JSON(resp.body)['total']

	if total_reviews < 6 then
		return false
	else
		return true
	end

end


def add_rt_info(imdb_movie_id, movie_hash)
	reviews_on_rt = check_if_rt_scores_exist_and_return(imdb_movie_id)
	if ! reviews_on_rt then
		return false
	end
	critics_score, audience_score, rt_movie_id = reviews_on_rt

	if ! check_if_six_reviews_exist(rt_movie_id) then
		puts "Less than six reviews"
		return false
	end
	
	return critics_score, audience_score
end


puts "Enter actor."
# actor_query = gets.chomp.downcase
# actor_name = actor_query.split(" ")
# actor_parameter = "&query=" + actor_name[0] + "+" + actor_name[-1]
# puts actor_parameter
actor_parameter = "&query=matt+damon"
actor_filmography = search_tmdb_for_actor_and_filmography(actor_parameter)
movie_ids_list = Array.new

actor_filmography['cast'].each do |movie_dict|
	movie_ids_list.push(movie_dict['id'])
end

movie_ids_list.each do |movie_id|
	prepare_movie_hash(movie_id)
end

##See if you replace the TMDB casts function with a RT casts function
##I can gets the casts info from the first RT json request. that saves making
##a separate request to TMDB. But I can not get the writers from RT