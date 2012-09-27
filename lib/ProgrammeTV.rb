# encoding: utf-8
require 'curb'

class ProgrammeTV
	
	def wday_from_label(label)
	  ['dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi'].index(label).to_i
	end
	
	def channel_id_from_name(name)
		['0', 'tf1', 'france2', 'france3', 'canalplus', 'france5', 'm6', 'arte', 'direct8', 'w9', 'tmc', 'nt1', 'nrj12', 'lcp-senat', 'france4', 'bfmtv', 'itele', 'direct-star', 'gulli', 'franceO'].index(name)
	end
	
	def night(wday_label)
	
		days_in_future = self.wday_from_label(wday_label) - Time.new.wday
		days_in_future += 7 if days_in_future < 0
		cache_label = (Time.new + days_in_future * 86400).strftime("night://%d-%m-%Y")
	
		channels = settings.cache.get(cache_label)
		
		if (!channels)
		  easy = Curl::Easy.new("http://www.programme.tv/tnt/soiree/#{wday_label}.php") do |c|
		    c.follow_location = true
		    c.max_redirects = nil
		  end
		  easy.http_get
			page = easy.body_str
			easy.close
				
			# suppression de ce qu'il y a avant et après la liste des programmes
			page.gsub(/\n/, '') =~ /<ul class=\"left\">(.*<ul class=\"right\">.*?)<\/ul>/
  		page = $1#.force_encoding("UTF-8")
			
			channels = Hash.new
			
			page.split(/<li class=\"box\">/i).each do |line|
				channels[channel_id_from_name($1)] = {
					'id' => channel_id_from_name($1),
          'link' => "http://www.programme.tv#{$3}",
          'title' => $4.strip,
          'start' => $2,
				} if line =~ /href=\"http:\/\/old.programme.tv\/chaine\/([^\/]+)\/\".*<span class=\"hour\">([0-9]{2}:[0-9]{2})<\/span>.*<h3>\s*(?:<a href=\"([^"]*)\"[^>]*>)?([^<]*)(?:<\/a>)?\s*<\/h3>/
			end
      settings.cache.set(cache_label, channels)
		end
	
		channels
	end
	
	def now
		easy = Curl::Easy.http_get("http://www.programme.tv/actuellement/tnt/")
		page = easy.body_str
		easy.close
		
		# suppression de ce qu'il y a avant et après la liste des programmes
		page.gsub(/\n/, '') =~ /<ul class=\"left\">(.*<ul class=\"right\">.*?)<\/ul>/
		page = $1.force_encoding("UTF-8")
		
		channels = Hash.new
		
		page.split(/<li class=\"box\">/i).each do |line|
			channels[channel_id_from_name($1)] = {
				'id' => channel_id_from_name($1),
				'start' => $2,
				'link' => "http://www.programme.tv#{$3}",
				'title' => $4.strip,
				'end' => $5,
				'percent' => $6,
			} if line =~ /href=\"http:\/\/old.programme.tv\/chaine\/([^\/]+)\/\".*<span class=\"hour\">([0-9]{2}:[0-9]{2})<\/span>.*<h3>\s*(?:<a href=\"([^"]*)\"[^>]*>)?([^<]*)(?:<\/a>)?\s*<\/h3>.*<span class=\"progressbar-end\">([0-9]{2}:[0-9]{2})<\/span>.*<div class=\"pr?ogressbar-percent\">([0-9]{1,3})%<\/div>/
		end
	
		channels		
	end
	
	def show(url)
    show = settings.cache.get(url)
		
		if !show
			easy = Curl::Easy.http_get(url)
			page = easy.body_str
			easy.close

			# suppression de ce qu'il y a avant et après ce qui nous intéresse
			page.gsub(/\n/, '') =~ /<div id=\"progselect\">(.*)<div id=\"pubcontent\">/
			page = $1.force_encoding("UTF-8")
			
			show = Hash.new
			
			# récupération du type du programme avec son pays et année de production
			show['type'] = $1 if page =~ /<span class=\"type[^"]*\">\s*([^<]*)\s*/
			
			# récupération des horaires			
			show['start'] = $1 if page =~ /<span class=\"date\">[^<]*?([0-9]{2}h[0-9]{2})<\/span>/
			show['duration'] = $1 if page =~ /<span class=\"infos\">Durée : ([^<]*)<\/span>/
			
			# récupération du titre du programme
			show['title'] = $1 if page =~ /<h1>([^<]*)/
			
			# récupération du numéro de programme pour l'image
			show['image'] = $1 if page =~ /\"illustration_1\".*?<img src=\"([^"]*)/
			
			# récupération du sous-titre du programme
			show['subtitle'] = $1 if page =~ /<h2>([^<]*)/
			
			# récupération de la saison et de l'épisode (applicable seulement aux séries)

			if page =~ /<span class=\"infos\">Saison : ([0-9]{1,3}) - Episode : ([0-9\/]{1,9})</
				show['season'] = $1
				show['episode'] = $2
			end
	
			# récupération du résumé
			if page =~ /<div class=\"resume\">.*?<p>(.*?)<\/p>/
				texte = $1
				# suppression des infos qu'on ne veut pas
				texte.gsub!(/(<b>Invit[^s]*s :<\/b>[^<]*<br \/><br \/>)|(<b>Pr[^s]*sent[^ ]* par :<\/b>[^<]*<br \/><br \/>)|(<b>R[^a]*alis[^ ]* par :<\/b>[^<]*<br \/><br \/>)|(<b>Acteurs :<\/b>[^<]*<br \/><br \/>)|(<b>Notre avis :<\/b>[^<]*<br \/><br \/>)|(<br \/>)/, '')
				texte.gsub!(/<span class=\"bold\">/, '<br/><b>')
				texte.gsub!(/<\/span>/, '</b><br/>')
				texte.gsub!(/<br\/?><br\/?>/, '<br/>')
				show['resume'] = texte
			end
      settings.cache.set(url, show)
		end
		
		show
	end
	
end