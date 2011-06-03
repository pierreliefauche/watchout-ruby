# encoding: utf-8
require 'curb'

class ProgrammeTV 
	
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
	
	def night(wday_label)
	
		days_in_future = self.wday_from_label(wday_label) - Time.new.wday
		days_in_future += 7 if days_in_future < 0
		cache_label = (Time.new + days_in_future * 86400).strftime("night://%d-%m-%Y")
	
		channels = settings.cache.get(cache_label)
		
		if (!channels)
			easy = Curl::Easy.http_get("http://www.programme.tv/soiree/#{wday_label}.php")
			page = easy.body_str
			easy.close
				
			# suppression de ce qu'il y a avant et après la liste des programmes
			page.gsub(/\n/, '') =~ /<table class=\"contenu_soiree\">[^<]*<tr>(.*)<div id=\"droite\">/
			page = $1.gsub(/<script[^<]*script>[^<]*<\/td>/, '</td>').force_encoding("UTF-8")
			
			channels = Hash.new
			
			page.split(/<td valign=\"top\"[^>]*class=\"soiree[^\"]*\">/).each do |line|
	# 			matches:
	# 			1: chaine
	# 			2: heure de début du programme
	# 			3: lien pour le programme
	# 			4: programme
				channels[$1.to_i] = {
					'id' => $1.to_i,
					'showLink' => $3,
					'show' => $4,
					'showStart' => $2.sub('.', 'h'),
				} if line =~ /chaine\/([0-9]{1,2})p?\.gif.*([0-9]{2}\.[0-9]{2}).*href=\"([^\"]*)\" class=\"bb12\">([^<]*)/
			end
			settings.cache.set(cache_label, channels)
		end
	
		channels
	end
	
	def now
		easy = Curl::Easy.http_get("http://www.programme.tv/actuellement/")
		page = easy.body_str
		easy.close
			
		# suppression de ce qu'il y a avant et après la liste des programmes
		page.gsub(/\n/, '') =~ /<table class=\"table_actu\">(.*)<div id=\"droite\">/
		page = $1.force_encoding("UTF-8")
		
		channels = Array.new
		
		page.split(/<tr>\s*<td class=\"width50p( bar\_gris)?\">/i).each do |line|			
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
				'id' => $1.to_i,
				'nowLink' => $2,
				'now' => $3,
				'nowStart' => $4,
				'nowEnd' => $6,
				'nowDone' => $5,
				'next' => $9,
				'nextStart' => $7,
				'nextLink' => $8,
				'nextNext' => $12,
				'nextNextStart' => $10,
				'nextNextLink' => $11,
			}) if line =~ /chaine\/([0-9]{1,2})p?\.gif.*href=\"([^\"]*)\".*<b>(.*)<\/b>.*([0-9]{2}h[0-9]{2}).*actu_chiffre\">([0-9]{1,3})%<\/span>.*&nbsp;([0-9]{2}h[0-9]{2}).*([0-9]{2}h[0-9]{2}).*href=\"([^\"]*)\".*<b>(.*)<\/b>.*([0-9]{2}h[0-9]{2}).*href=\"([^\"]*)\".*<b>(.*)<\/b>/
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
			begin 
				show['start'] = $1;
				show['end'] = $2;
			end if page =~ /<span class=\"eHeure\">([0-9]{2}h[0-9]{2})<\/span>.*([0-9]{2}h[0-9]{2})<br \/>/
			
			# récupération du titre du programme
			show['title'] = $1 if page =~ /<div class=\"b18\">([^<]*)</
			
			# récupération du numéro de programme pour l'image
			show['image'] = $1 if page =~ /<td class=\"center\">[^<]*<img src=\"([^>]*\.jpg)\"/
			
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