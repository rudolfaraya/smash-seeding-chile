require 'net/http'
require 'uri'
require 'nokogiri'
require 'fileutils'

namespace :smash do
  desc 'Extract character full art skins from SSBWiki'
  task extract_character_skins: :environment do
    puts "🎮 Iniciando extracción de skins full art de personajes..."
    
    # URL de la página de skins
    url = 'https://www.ssbwiki.com/Alternate_costume_(SSBU)'
    
    # Mapeo de nombres para evitar confusiones
    character_name_mapping = {
      'Banjo & Kazooie' => 'banjo_kazooie',
      'Bayonetta' => 'bayonetta',
      'Bowser' => 'bowser',
      'Bowser Jr.' => 'bowser_jr',
      'Byleth' => 'byleth',
      'Captain Falcon' => 'captain_falcon',
      'Chrom' => 'chrom',
      'Cloud' => 'cloud',
      'Corrin' => 'corrin',
      'Daisy' => 'daisy',
      'Dark Pit' => 'dark_pit',
      'Dark Samus' => 'dark_samus',
      'Diddy Kong' => 'diddy_kong',
      'Donkey Kong' => 'donkey_kong',
      'Dr. Mario' => 'dr_mario',
      'Duck Hunt' => 'duck_hunt',
      'Falco' => 'falco',
      'Fox' => 'fox',
      'Ganondorf' => 'ganondorf',
      'Greninja' => 'greninja',
      'Hero' => 'hero',
      'Ice Climbers' => 'ice_climbers',
      'Ike' => 'ike',
      'Incineroar' => 'incineroar',
      'Inkling' => 'inkling',
      'Isabelle' => 'isabelle',
      'Jigglypuff' => 'jigglypuff',
      'Joker' => 'joker',
      'Kazuya' => 'kazuya',
      'Ken' => 'ken',
      'King Dedede' => 'king_dedede',
      'King K. Rool' => 'king_k_rool',
      'Kirby' => 'kirby',
      'Link' => 'link',
      'Little Mac' => 'little_mac',
      'Lucario' => 'lucario',
      'Lucas' => 'lucas',
      'Lucina' => 'lucina',
      'Luigi' => 'luigi',
      'Mario' => 'mario',
      'Marth' => 'marth',
      'Mega Man' => 'mega_man',
      'Meta Knight' => 'meta_knight',
      'Mewtwo' => 'mewtwo',
      'Mii Fighter' => 'mii_fighter',
      'Min Min' => 'min_min',
      'Mr. Game & Watch' => 'mr_game_watch',
      'Ness' => 'ness',
      'Olimar' => 'olimar',
      'Pac-Man' => 'pac_man',
      'Palutena' => 'palutena',
      'Peach' => 'peach',
      'Pichu' => 'pichu',
      'Pikachu' => 'pikachu',
      'Piranha Plant' => 'piranha_plant',
      'Pit' => 'pit',
      'Pokémon Trainer' => 'pokemon_trainer',
      'Pyra/Mythra' => 'pyra_mythra',
      'Richter' => 'richter',
      'Ridley' => 'ridley',
      'R.O.B.' => 'rob',
      'Robin' => 'robin',
      'Rosalina & Luma' => 'rosalina_luma',
      'Roy' => 'roy',
      'Ryu' => 'ryu',
      'Samus' => 'samus',
      'Sephiroth' => 'sephiroth',
      'Sheik' => 'sheik',
      'Shulk' => 'shulk',
      'Simon' => 'simon',
      'Snake' => 'snake',
      'Sonic' => 'sonic',
      'Sora' => 'sora',
      'Steve' => 'steve',
      'Terry' => 'terry',
      'Toon Link' => 'toon_link',
      'Villager' => 'villager',
      'Wario' => 'wario',
      'Wii Fit Trainer' => 'wii_fit_trainer',
      'Wolf' => 'wolf',
      'Yoshi' => 'yoshi',
      'Young Link' => 'young_link',
      'Zelda' => 'zelda',
      'Zero Suit Samus' => 'zero_suit_samus'
    }
    
    begin
      # Crear directorio para las imágenes
      skins_dir = Rails.root.join('app', 'assets', 'images', 'smash', 'character_skins')
      FileUtils.mkdir_p(skins_dir)
      
      # Obtener el contenido de la página
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      unless response.code == '200'
        puts "❌ Error al acceder a la página: #{response.code}"
        return
      end
      
      # Parsear el HTML
      doc = Nokogiri::HTML(response.body)
      
      # Buscar todas las imágenes de paletas de personajes
      palette_images = doc.css('img[alt*="Palette (SSBU)"]')
      
      puts "🔍 Encontradas #{palette_images.length} imágenes de paletas"
      
      downloaded_count = 0
      
      palette_images.each do |img|
        begin
          # Extraer el nombre del personaje del alt text
          alt_text = img['alt']
          character_name = alt_text.gsub(' Palette (SSBU).png', '').strip
          
          # Buscar el nombre mapeado
          mapped_name = character_name_mapping[character_name]
          
          if mapped_name.nil?
            puts "⚠️  Personaje no encontrado en mapeo: #{character_name}"
            next
          end
          
          # Obtener la URL de la imagen original (no thumbnail)
          img_src = img['src']
          
          # Convertir a URL de imagen completa
          if img_src.include?('/thumb/')
            # Extraer la URL original desde el srcset o construirla
            srcset = img['srcset']
            if srcset && srcset.include?('2x')
              # Tomar la imagen 2x del srcset
              full_url = srcset.split(' 2x')[0].split(', ').last
            else
              # Construir URL original removiendo /thumb/ y el tamaño
              full_url = img_src.gsub('/thumb/', '/').gsub(/\/\d+px-.*$/, '')
            end
          else
            full_url = img_src
          end
          
          # Asegurar que sea URL absoluta
          unless full_url.start_with?('http')
            full_url = "https://ssb.wiki.gallery#{full_url}"
          end
          
          puts "📥 Descargando #{character_name} (#{mapped_name})..."
          puts "    URL: #{full_url}"
          
          # Descargar la imagen
          image_uri = URI(full_url)
          image_response = Net::HTTP.get_response(image_uri)
          
          if image_response.code == '200'
            # Guardar la imagen
            filename = "#{mapped_name}_fullart.png"
            filepath = File.join(skins_dir, filename)
            
            File.open(filepath, 'wb') do |file|
              file.write(image_response.body)
            end
            
            downloaded_count += 1
            puts "✅ Guardado: #{filename}"
          else
            puts "❌ Error descargando #{character_name}: #{image_response.code}"
          end
          
        rescue => e
          puts "❌ Error procesando #{character_name}: #{e.message}"
        end
        
        # Pequeña pausa para no sobrecargar el servidor
        sleep(0.5)
      end
      
      puts "\n🎉 Extracción completada!"
      puts "📊 Total de imágenes descargadas: #{downloaded_count}"
      puts "📁 Ubicación: #{skins_dir}"
      
      # Mostrar instrucciones para el siguiente paso
      puts "\n📋 Próximos pasos:"
      puts "1. Las imágenes están guardadas en #{skins_dir}"
      puts "2. Cada imagen contiene 8 skins del personaje en una fila"
      puts "3. Puedes usar ImageMagick para cortarlas en 8 partes:"
      puts "   convert imagen_fullart.png -crop 8x1@ +repage skin_%d.png"
      
    rescue => e
      puts "❌ Error general: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
  
  desc 'Split character full art images into individual skins'
  task split_character_skins: :environment do
    puts "✂️  Iniciando división de imágenes full art en skins individuales..."
    
    skins_dir = Rails.root.join('app', 'assets', 'images', 'smash', 'character_skins')
    individual_skins_dir = Rails.root.join('app', 'assets', 'images', 'smash', 'character_individual_skins')
    
    # Crear directorio para skins individuales
    FileUtils.mkdir_p(individual_skins_dir)
    
    # Verificar si ImageMagick está disponible
    unless system('which convert > /dev/null 2>&1')
      puts "❌ ImageMagick no está instalado. Instálalo con:"
      puts "   Ubuntu/Debian: sudo apt-get install imagemagick"
      puts "   macOS: brew install imagemagick"
      return
    end
    
    processed_count = 0
    
    Dir.glob(File.join(skins_dir, '*_fullart.png')).each do |fullart_path|
      begin
        # Extraer nombre del personaje
        filename = File.basename(fullart_path, '_fullart.png')
        
        puts "✂️  Procesando #{filename}..."
        
        # Crear directorio para este personaje
        character_dir = File.join(individual_skins_dir, filename)
        FileUtils.mkdir_p(character_dir)
        
        # Comando para dividir la imagen en 8 partes
        output_pattern = File.join(character_dir, "#{filename}_skin_%d.png")
        command = "convert '#{fullart_path}' -crop 8x1@ +repage '#{output_pattern}'"
        
        if system(command)
          puts "✅ #{filename} dividido en 8 skins"
          processed_count += 1
        else
          puts "❌ Error dividiendo #{filename}"
        end
        
      rescue => e
        puts "❌ Error procesando #{File.basename(fullart_path)}: #{e.message}"
      end
    end
    
    puts "\n🎉 División completada!"
    puts "📊 Total de personajes procesados: #{processed_count}"
    puts "📁 Skins individuales en: #{individual_skins_dir}"
  end
end 