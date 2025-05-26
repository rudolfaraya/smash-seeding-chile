namespace :smash do
  desc "Descarga assets de personajes de Smash Ultimate desde SSB Wiki usando web scraping"
  task download_assets: :environment do
    require "open-uri"
    require "fileutils"
    require "nokogiri"

    # Crear directorio si no existe
    assets_dir = Rails.root.join("app", "assets", "images", "smash", "characters")
    FileUtils.mkdir_p(assets_dir)

    puts "🚀 Iniciando descarga de assets de Smash Ultimate..."
    puts "📁 Directorio de destino: #{assets_dir}"

    # URL de la página principal con todos los personajes
    base_url = "https://www.ssbwiki.com/Alternate_costume_(SSBU)"

    begin
      puts "🌐 Obteniendo página principal de SmashWiki..."

      # Agregar User-Agent para evitar bloqueos
      html = URI.open(base_url, {
        "User-Agent" => "Mozilla/5.0 (compatible; SmashSeedingChile/1.0; +http://localhost:3000)"
      }).read

      doc = Nokogiri::HTML(html)
      puts "✅ Página cargada exitosamente"

      # Mapeo de nombres de personajes desde el modelo Player
      character_mapping = {
        "Banjo & Kazooie" => "banjo_kazooie",
        "Bayonetta" => "bayonetta",
        "Bowser" => "bowser",
        "Bowser Jr." => "bowser_jr",
        "Byleth" => "byleth",
        "Captain Falcon" => "captain_falcon",
        "Chrom" => "chrom",
        "Cloud" => "cloud",
        "Corrin" => "corrin",
        "Daisy" => "daisy",
        "Dark Pit" => "dark_pit",
        "Dark Samus" => "dark_samus",
        "Diddy Kong" => "diddy_kong",
        "Donkey Kong" => "donkey_kong",
        "Dr. Mario" => "dr_mario",
        "Duck Hunt" => "duck_hunt",
        "Falco" => "falco",
        "Fox" => "fox",
        "Ganondorf" => "ganondorf",
        "Greninja" => "greninja",
        "Hero" => "hero",
        "Ice Climbers" => "ice_climbers",
        "Ike" => "ike",
        "Incineroar" => "incineroar",
        "Inkling" => "inkling",
        "Isabelle" => "isabelle",
        "Jigglypuff" => "jigglypuff",
        "Joker" => "joker",
        "Kazuya" => "kazuya",
        "Ken" => "ken",
        "King Dedede" => "king_dedede",
        "King K. Rool" => "king_k_rool",
        "Kirby" => "kirby",
        "Link" => "link",
        "Little Mac" => "little_mac",
        "Lucario" => "lucario",
        "Lucas" => "lucas",
        "Lucina" => "lucina",
        "Luigi" => "luigi",
        "Mario" => "mario",
        "Marth" => "marth",
        "Mega Man" => "mega_man",
        "Meta Knight" => "meta_knight",
        "Mewtwo" => "mewtwo",
        "Min Min" => "min_min",
        "Mr. Game & Watch" => "mr_game_and_watch",
        "Ness" => "ness",
        "Olimar" => "olimar",
        "Pac-Man" => "pac_man",
        "Palutena" => "palutena",
        "Peach" => "peach",
        "Pichu" => "pichu",
        "Pikachu" => "pikachu",
        "Piranha Plant" => "piranha_plant",
        "Pit" => "pit",
        "Pokémon Trainer" => "pokemon_trainer",
        "Pyra/Mythra" => "pyra_mythra",
        "R.O.B." => "rob",
        "Richter" => "richter",
        "Ridley" => "ridley",
        "Robin" => "robin",
        "Rosalina & Luma" => "rosalina_luma",
        "Roy" => "roy",
        "Ryu" => "ryu",
        "Samus" => "samus",
        "Sephiroth" => "sephiroth",
        "Sheik" => "sheik",
        "Shulk" => "shulk",
        "Simon" => "simon",
        "Snake" => "snake",
        "Sonic" => "sonic",
        "Sora" => "sora",
        "Steve" => "steve",
        "Terry" => "terry",
        "Toon Link" => "toon_link",
        "Villager" => "villager",
        "Wario" => "wario",
        "Wii Fit Trainer" => "wii_fit_trainer",
        "Wolf" => "wolf",
        "Yoshi" => "yoshi",
        "Young Link" => "young_link",
        "Zelda" => "zelda",
        "Zero Suit Samus" => "zero_suit_samus"
      }

      downloaded_count = 0
      error_count = 0

      # Procesar cada personaje
      character_mapping.each do |display_name, character_key|
        puts "\n🎮 Procesando #{display_name}..."

        begin
          # Buscar el h2 que contenga el nombre del personaje
          character_header = doc.css("h2").find do |h2|
            # Normalizar el texto removiendo espacios extra y caracteres especiales
            header_text = h2.text.strip.gsub(/\s+/, " ")
            display_text = display_name.strip.gsub(/\s+/, " ")

            # Comparación exacta o contenga el nombre
            header_text == display_text || header_text.include?(display_text)
          end

          unless character_header
            puts "  ⚠️  Header no encontrado para #{display_name}, buscando por contenido..."

            # Búsqueda alternativa por contenido del span dentro del h2
            character_header = doc.css("h2 span.mw-headline").find do |span|
              span_text = span.text.strip.gsub(/\s+/, " ")
              display_text = display_name.strip.gsub(/\s+/, " ")
              span_text == display_text || span_text.include?(display_text)
            end&.parent
          end

          unless character_header
            puts "  ❌ No se pudo encontrar el header para #{display_name}"
            error_count += 1
            next
          end

          puts "  ✅ Header encontrado: #{character_header.text.strip}"

          # Buscar la tabla que contiene las imágenes de head icons
          # La tabla debe estar después del header del personaje
          current_element = character_header.next_element
          table = nil

          # Buscar en los próximos elementos hasta encontrar una tabla con imágenes de head
          10.times do
            break unless current_element

            if current_element.name == "table"
              # Verificar si esta tabla contiene imágenes de head icons
              head_images = current_element.css('img[alt*="Head"]')
              if head_images.any?
                table = current_element
                break
              end
            elsif current_element.name == "div"
              # Buscar tabla dentro de divs
              table_in_div = current_element.css("table").find do |t|
                t.css('img[alt*="Head"]').any?
              end
              if table_in_div
                table = table_in_div
                break
              end
            end

            current_element = current_element.next_element
          end

          unless table
            puts "  ❌ No se encontró tabla con íconos para #{display_name}"
            error_count += 1
            next
          end

          # Extraer todas las imágenes de head icons de la tabla
          head_images = table.css('img[alt*="Head"]').select do |img|
            img["alt"]&.include?("Head") &&
            img["alt"]&.include?("SSBU") &&
            img["src"]&.include?("ssb.wiki.gallery")
          end

          if head_images.empty?
            puts "  ❌ No se encontraron íconos de head para #{display_name}"
            error_count += 1
            next
          end

          puts "  📸 Encontrados #{head_images.length} íconos de head"

          # Descargar cada ícono (máximo 8 skins)
          head_images.first(8).each_with_index do |img, index|
            skin_number = index + 1

            # Obtener la URL de mejor calidad desde srcset o src
            image_url = nil

            if img["srcset"] && !img["srcset"].empty?
              # Extraer la URL de mejor calidad del srcset
              srcset_urls = img["srcset"].split(",").map(&:strip)
              # Buscar la URL que no tenga thumb/ (es la de mejor calidad)
              best_url = srcset_urls.find { |url| !url.include?("/thumb/") }
              if best_url
                image_url = best_url.split(" ").first # Remover el multiplicador (1.5x, 2x, etc.)
              end
            end

            # Si no hay srcset o no encontramos URL sin thumb, usar src pero mejorada
            unless image_url
              image_url = img["src"]
              # Convertir URL de thumbnail a URL de imagen completa
              if image_url.include?("/thumb/")
                # Remover /thumb/ y el tamaño para obtener la imagen original
                image_url = image_url.gsub("/thumb/", "/")
                # Remover el prefijo de tamaño (ej: /50px-)
                image_url = image_url.gsub(%r{/\d+px-[^/]+$}, "")
                # Reconstruir la URL correcta
                parts = image_url.split("/")
                if parts.length >= 2
                  filename = parts.last
                  path_parts = parts[0..-2]
                  image_url = "#{path_parts.join('/')}/#{filename}"
                end
              end
            end

            # Asegurarse de que la URL sea completa
            unless image_url.start_with?("http")
              image_url = "https:#{image_url}" if image_url.start_with?("//")
              image_url = "https://ssb.wiki.gallery#{image_url}" unless image_url.start_with?("http")
            end

            filename = "#{character_key}_#{skin_number}.png"
            filepath = assets_dir.join(filename)

            begin
              puts "  📥 Descargando skin #{skin_number}: #{image_url}"

              URI.open(image_url, {
                "User-Agent" => "Mozilla/5.0 (compatible; SmashSeedingChile/1.0; +http://localhost:3000)",
                "Referer" => base_url
              }) do |image|
                File.open(filepath, "wb") do |file|
                  file.write(image.read)
                end
              end

              # Verificar que se descargó un archivo PNG válido
              if File.exist?(filepath) && File.size(filepath) > 100
                puts "    ✅ #{filename} (#{File.size(filepath)} bytes)"
                downloaded_count += 1
              else
                puts "    ❌ #{filename} - archivo inválido o muy pequeño"
                File.delete(filepath) if File.exist?(filepath)
                error_count += 1
              end

            rescue => e
              puts "    ❌ Error descargando #{filename}: #{e.message}"
              error_count += 1
            end

            # Pausa para no sobrecargar el servidor
            sleep(0.3)
          end

        rescue => e
          puts "  ❌ Error procesando #{display_name}: #{e.message}"
          error_count += 1
        end
      end

      puts "\n" + "="*60
      puts "🎯 RESUMEN DE DESCARGA:"
      puts "✅ Archivos descargados exitosamente: #{downloaded_count}"
      puts "❌ Errores encontrados: #{error_count}"
      puts "📁 Assets guardados en: #{assets_dir}"
      puts "="*60

    rescue => e
      puts "❌ Error crítico: #{e.message}"
      puts e.backtrace.first(5)
    end
  end
end
