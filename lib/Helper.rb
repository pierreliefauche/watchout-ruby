# encoding: utf-8
require 'curb'

class Helper 

	attr_reader :wtoday
	
	def initialize
		@wtoday = Time.new.wday
	end
	
	def label_from_wday(wday)
		case wday
			when 0
				'dimanche'
			when 1
				'lundi'
			when 2
				'mardi'
			when 3
				'mercredi'
			when 4
				'jeudi'
			when 5
				'vendredi'
			when 6
				'samedi'
		end
	end
	
	def wday_from_label(label)
		case label
			when 'dimanche'
				0
			when 'lundi'
				1
			when 'mardi'
				2
			when 'mercredi'
				3
			when 'jeudi'
				4
			when 'vendredi'
				5
			when 'samedi'
				6
		end
	end
	
	def random_string
		return (100+rand(899)).to_s
	end
	
	def night(wday)
	
		days_in_future = self.wday_from_label(wday) - self.wtoday
		days_in_future += 7 if days_in_future < 0
		asked = Time.new
		asked += days_in_future * 86400
		cache_label = asked.strftime("night://%d-%m-%Y")
	
		channels = settings.cache.get(cache_label)
		
		if (!channels)
			easy = Curl::Easy.http_get("http://www.programme.tv/soiree/#{wday}.php")
			page = easy.body_str
			easy.close
				
			# suppression de ce qu'il y a avant et après la liste des programmes
			page.gsub(/\n/, '') =~ /<table class=\"contenu_soiree\">[^<]*<tr>(.*)<div id=\"droite\">/
			page = $1
			page.gsub!(/<script[^<]*script>[^<]*<\/td>/, '</td>')
			page = page.force_encoding("UTF-8")
			
			channels = Hash.new
			
			page.split(/<td valign=\"top\"[^>]*class=\"soiree[^\"]*\">/).each do |line|
				re = /chaine\/([0-9]{1,2})p?\.gif.*([0-9]{2}\.[0-9]{2}).*href=\"([^\"]*)\" class=\"bb12\">([^<]*)/
				matches = re.match(line)
	# 			matches:
	# 			1: chaine
	# 			2: heure de début du programme
	# 			3: lien pour le programme
	# 			4: programme
				channels[matches[1].to_i] = {
					'id' => matches[1].to_i,
					'showLink' => matches[3],
					'show' => matches[4],
					'showStart' => matches[2].sub('.', 'h'),
				} if matches
			end
			settings.cache.set(cache_label, channels)
		end
	
		channels
	end
	
	def now
		channels = nil#= settings.cache.get('night')
		
		if (!channels)
			easy = Curl::Easy.http_get("http://www.programme.tv/actuellement/")
			page = easy.body_str
			easy.close
				
			# suppression de ce qu'il y a avant et après la liste des programmes
			page.gsub(/\n/, '') =~ /<table class=\"table_actu\">(.*)<div id=\"droite\">/
			page = $1
			page = page.force_encoding("UTF-8")
			
			channels = Array.new
			
			page.split(/<tr>\s*<td class=\"width50p( bar\_gris)?\">/i).each do |line|
				re = /chaine\/([0-9]{1,2})p?\.gif.*href=\"([^\"]*)\".*<b>(.*)<\/b>.*([0-9]{2}h[0-9]{2}).*actu_chiffre\">([0-9]{1,3})%<\/span>.*&nbsp;([0-9]{2}h[0-9]{2}).*([0-9]{2}h[0-9]{2}).*href=\"([^\"]*)\".*<b>(.*)<\/b>.*([0-9]{2}h[0-9]{2}).*href=\"([^\"]*)\".*<b>(.*)<\/b>/
				matches = re.match(line)
				
# 		matches:
# 		1: chaine 
# 		2: lien pour le programme actuel
# 		3: programme actuel
# 		4: heure début programme actuel
# 		5: pourcentage d'avancement du programme actuel
# 		6: heure fin programme actuel
# 		7: heure début programme qui suit
# 		8: lien pour le programme qui suit
# 		9: programme qui suit
# 		10: heure début programme d'encore après
# 		11: lien pour le programme d'encore après
# 		12: programme d'encore après
				channels.push({
					'id' => matches[1].to_i,
					'nowLink' => matches[2],
					'now' => matches[3],
					'nowStart' => matches[4],
					'nowEnd' => matches[6],
					'nowDone' => matches[5],
					'next' => matches[9],
					'nextStart' => matches[7],
					'nextLink' => matches[8],
					'nextNext' => matches[12],
					'nextNextStart' => matches[10],
					'nextNextLink' => matches[11],
				}) if matches
			end
			# settings.cache.set('night', channels)
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
			page.gsub(/\n/, '') =~ /table width=\"100%\" class=\"eTable\">(.*)<td class=\"b12\">Les autres diffusions/
			page = $1.force_encoding("UTF-8")
			
			show = Hash.new
			
			# récupération du type du programme avec son pays et année de production
			show['type'] = $1 if page =~ /<td colspan=\"2\" align=\"right\" class=\"b12 efond\">(.*)&nbsp;<\/td>/
			
			# récupération des horaires exacts
			if page =~ /<span class=\"eHeure\">([0-9]{2}h[0-9]{2})<\/span>.*([0-9]{2}h[0-9]{2})<br \/>/
				show['start'] = $1;
				show['end'] = $2;
			end
			
			# récupération du titre du programme
			show['title'] = $1 if page =~ /<div class=\"b18\">([^<]*)</
			
			# récupération du numéro de programme pour l'image
			show['image'] = $1 if page =~ /<td class=\"center\">[^<]*<img src=\"(.*\.jpg)\"/
			
			# récupération du sous-titre du programme
			show['subtitle'] = $1 if page =~ /<\/div><div class=\"b12\">(.+)<\/div>/
			
			# récupération de la saison et de l'épisode (applicable seulement aux séries)
			if page =~ /<br \/>Saison : ([0-9]{1,3})[^<]*<br \/>Episode : ([0-9\/]{1,9})[^<]*<br \/>/
				show['season'] = $1
				show['episode'] = $2
			end
	
			# récupération du résumé
			if page =~ /<span id=\"intelliTXT\">(.*)<\/?span\/?>/
				texte = $1
				# suppression des infos qu'on ne veut pas
				texte.gsub!(/(<b>Invit[^s]*s :<\/b>[^<]*<br \/><br \/>)|(<b>Pr[^s]*sent[^ ]* par :<\/b>[^<]*<br \/><br \/>)|(<b>R[^a]*alis[^ ]* par :<\/b>[^<]*<br \/><br \/>)|(<b>Acteurs :<\/b>[^<]*<br \/><br \/>)|(<b>Notre avis :<\/b>[^<]*<br \/><br \/>)|(<br \/>)/, '')
				texte.gsub!(/<b>/, '<br/><b>')
				texte.gsub!(/<\/b>/, '</b><br/>')
				texte.gsub!(/<br\/><br\/>/, '<br/>')
				show['resume'] = texte
			end
			settings.cache.set(url, show)
		end
		
		show
	end
	
end