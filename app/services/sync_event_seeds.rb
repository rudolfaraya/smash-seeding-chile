require_relative "../../lib/start_gg_queries"
require 'set'

class SyncEventSeeds
  def initialize(event, force: false)
    @event = event
    @client = StartGgClient.new
    @force = force
  end

  def call
    Rails.logger.info "Sincronizando seeds y jugadores para el evento: #{@event.name} (force: #{@force})"
    
    # Si es una sincronización forzada, limpiar seeds existentes
    if @force
      Rails.logger.info "Sincronización forzada: eliminando #{@event.event_seeds.count} seeds existentes"
      @event.event_seeds.destroy_all
    end
    
    # Intentar primero con la consulta de entrants (más directa)
    begin
      seeds_data = fetch_seeds_from_entrants(@event.tournament.slug, @event.slug)
    rescue StandardError => e
      Rails.logger.warn "Error al obtener seeds mediante entrants: #{e.message}. Intentando método alternativo..."
      # Si falla, intentar con el método de phases y groups
      seeds_data = fetch_seeds_sequentially(@event.tournament.slug, @event.slug)
    end
    
    if seeds_data.empty?
      Rails.logger.warn "No se encontraron seeds para el evento: #{@event.name}"
      raise "No se encontraron seeds para el evento. Verifica que el evento tenga participantes con seeding."
    end
    
    # Para evitar duplicados, mantener un registro de los seeds procesados
    processed_seeds = Set.new
    
    seeds_data.each do |seed_data|
      begin
        entrant = seed_data["entrant"]
        next unless entrant && entrant["participants"].present?

        player_data = entrant["participants"].first["player"]
        user = player_data["user"] || {}
        
        # Crear un identificador único para evitar duplicados
        unique_key = "#{user["id"]}_#{entrant["id"]}"
        
        if processed_seeds.include?(unique_key)
          Rails.logger.warn "Seed duplicado saltado: #{entrant["name"]} (#{unique_key})"
          next
        end
        processed_seeds << unique_key
        
        Rails.logger.info "Procesando jugador: #{entrant["name"]} (User ID: #{user["id"] || 'No disponible'})"
        
        # Validar datos antes de crear el jugador
        if user["id"].nil?
          Rails.logger.warn "User ID no disponible para #{entrant["name"]}, saltando"
          next
        end
        
        # Preparar atributos de forma segura
        player_attributes = {
          id: player_data["id"],
          entrant_name: entrant["name"],
          name: user["name"],
          discriminator: user["discriminator"],
          bio: user["bio"],
          birthday: user["birthday"],
          twitter_handle: user["authorizations"]&.first&.dig("externalUsername")
        }
        
        # Agregar atributos de ubicación si están disponibles
        if user["location"].present?
          player_attributes[:city] = user["location"]["city"]
          player_attributes[:state] = user["location"]["state"]
          player_attributes[:country] = user["location"]["country"]
        end
        
        # Buscar o crear el jugador
        player = Player.find_or_create_by(user_id: user["id"]) do |p|
          # Asignar atributos básicos
          player_attributes.each do |attr, value|
            begin
              p[attr] = value if value.present?
            rescue => e
              Rails.logger.warn "No se pudo asignar #{attr}: #{e.message}"
            end
          end
          
          # Asignar el pronombre de género con el método seguro
          p.assign_gender_pronoun(user["genderPronoun"]) if user["genderPronoun"].present?
        end

        Rails.logger.info "Jugador creado/actualizado: #{player.id} - #{player.entrant_name}"
        
        # Crear o actualizar el EventSeed
        event_seed = EventSeed.find_or_create_by(event: @event, player: player) do |es|
          es.seed_num = seed_data["seedNum"] || nil
          es.character_stock_icon = nil
        end
        
        # Actualizar el seed_num si ha cambiado
        if event_seed.seed_num != (seed_data["seedNum"] || nil)
          Rails.logger.info "Actualizando seed_num de #{event_seed.seed_num} a #{seed_data["seedNum"]} para #{player.entrant_name}"
          event_seed.update!(seed_num: seed_data["seedNum"] || nil)
        end
        
        Rails.logger.info "EventSeed creado/actualizado: #{event_seed.id} - Seed #{event_seed.seed_num}"
      rescue StandardError => e
        Rails.logger.error "Error procesando seed para evento #{@event.name}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        # No hacemos raise para continuar con el siguiente seed
        next
      end
    end
    
    final_count = EventSeed.where(event: @event).count
    Rails.logger.info "Sincronización completada: #{final_count} seeds para el evento #{@event.name}"
    final_count
  end

  private
  
  # Método alternativo que obtiene seeds a través de entrants
  def fetch_seeds_from_entrants(tournament_slug, event_slug, per_page = 100)
    all_seeds = []
    page = 1
    total_pages = nil

    loop do
      begin
        Rails.logger.info "Obteniendo seeds mediante entrants para #{event_slug}, página #{page}"
        variables = { 
          tournamentSlug: tournament_slug, 
          eventSlug: event_slug, 
          perPage: per_page, 
          page: page 
        }
        response = @client.query(StartGgQueries::EVENT_SEEDING_QUERY, variables, "EventSeeding")
        
        if response.is_a?(Hash) && response["errors"]
          Rails.logger.error "Errores en la respuesta: #{response["errors"]}"
          raise "API retornó errores: #{response["errors"]}"
        end
        
        event = response["data"]["tournament"]["events"].first
        return [] unless event && event["entrants"] && event["entrants"]["nodes"]
        
        event["entrants"]["nodes"].each do |entrant|
          # Verificar si el entrant tiene información de participantes
          if !entrant["participants"].present?
            Rails.logger.warn "Entrant #{entrant["name"]} (#{entrant["id"]}) no tiene participantes, saltando"
            next
          end
          
          # Verificar si el primer participante tiene información de jugador
          participant = entrant["participants"].first
          if !participant["player"]
            Rails.logger.warn "Participante en entrant #{entrant["name"]} no tiene información de jugador, saltando"
            next
          end
          
          # Construir el seed data con información segura
          seed_data = {
            "id" => entrant["id"],
            "seedNum" => entrant["initialSeedNum"],
            "entrant" => {
              "id" => entrant["id"],
              "name" => entrant["name"],
              "participants" => []
            }
          }
          
          # Solo agregar información de participantes si existe
          entrant["participants"].each do |p|
            if p["player"]
              seed_data["entrant"]["participants"] << p
            end
          end
          
          # Solo agregar a los seeds si tiene al menos un participante con información
          if seed_data["entrant"]["participants"].present?
            all_seeds << seed_data
          else
            Rails.logger.warn "Entrant #{entrant["name"]} no tiene participantes válidos, saltando"
          end
        end
        
        total_pages = event["entrants"]["pageInfo"]["totalPages"] || 1
      rescue StandardError => e
        Rails.logger.error "Error al obtener seeds mediante entrants: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise
      end
      
      break if page >= total_pages
      page += 1
      sleep 0.75 # Retraso entre solicitudes
    end
    
    Rails.logger.info "Se encontraron #{all_seeds.size} seeds mediante entrants para el evento: #{event_slug}"
    all_seeds
  end

  def fetch_seeds_sequentially(tournament_slug, event_slug, requests_per_minute = 80)
    all_seeds = []
    page = 1
    per_page = 50
    total_pages = nil

    loop do
      begin
        Rails.logger.info "Enviando solicitud a Start.gg con URL: https://api.start.gg/gql/alpha"
        variables = { 
          tournamentSlug: tournament_slug, 
                                eventSlug: event_slug, 
                                perPage: per_page, 
          page: page 
        }
        request_body = { 
          query: StartGgQueries::EVENT_PARTICIPANTS_QUERY, 
          variables: variables, 
          operationName: "EventParticipants"
        }.to_json
        Rails.logger.info "Enviando solicitud a Start.gg con body: #{request_body}"
        response = @client.query(StartGgQueries::EVENT_PARTICIPANTS_QUERY, variables, "EventParticipants")
        
        Rails.logger.info "Respuesta completa (cuerpo): #{response}"
        Rails.logger.info "Respuesta completa (headers): #{response.headers}" if response.respond_to?(:headers)
        
        if response.is_a?(Hash) && response["errors"]
          Rails.logger.error "Errores en la respuesta: #{response["errors"]}"
          raise "API retornó errores: #{response["errors"]}"
        end
        
        event = response["data"]["tournament"]["events"].first
        
        # Verificar que existan phases antes de procesarlas
        if event["phases"].nil? || event["phases"].empty?
          Rails.logger.warn "No se encontraron phases para el evento: #{event_slug}"
          break
        end
        
        # Procesamos cada fase y grupo de fase para extraer los seeds
        event["phases"].each do |phase|
          # Verificar que phaseGroups exista y tenga nodes
          next unless phase["phaseGroups"] && phase["phaseGroups"]["nodes"]
          
          phase["phaseGroups"]["nodes"].each do |group|
            # Verificar que seeds exista y tenga nodes
            next unless group["seeds"] && group["seeds"]["nodes"]
            
            group["seeds"]["nodes"].each do |seed|
              # Verificar que el seed tenga la información necesaria
              next unless seed["entrant"] && seed["id"] && seed["seedNum"]
              
              all_seeds << {
                "id" => seed["id"],
                "seedNum" => seed["seedNum"],
                "entrant" => seed["entrant"]
          }
        end
          end
        end
        
        # Determinamos si hay más páginas para cargar
        if event["phases"].first && 
           event["phases"].first["phaseGroups"] && 
           event["phases"].first["phaseGroups"]["pageInfo"]
          total_pages = event["phases"].first["phaseGroups"]["pageInfo"]["totalPages"] || 1
        else
          total_pages = 1
        end
        
      rescue Faraday::ClientError => e
        if e.response && e.response[:status] == 429
          retry_after = e.response[:headers] && e.response[:headers]["Retry-After"]&.to_i || 60
          Rails.logger.warn "Rate limit excedido para torneo #{tournament_slug}, evento #{event_slug}, página #{page}. Esperando #{retry_after} segundos..."
          sleep(retry_after)
          next
        elsif e.response && [404, 500].include?(e.response[:status])
          Rails.logger.error "Error HTTP #{e.response[:status]} al obtener seeds para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.response[:body]}"
          raise "Error HTTP al obtener seeds: #{e.response[:status]} - #{e.response[:body]}"
        else
          Rails.logger.error "Error al obtener seeds para torneo #{tournament_slug}, evento #{event_slug}, página #{page}: #{e.message}"
          raise
        end
      end
      
      break if page >= total_pages
      page += 1
      sleep 0.75 # Retraso de 0.75 segundos entre solicitudes (80 solicitudes/minuto = ~0.75s por solicitud)
    end
    
    if all_seeds.empty?
      Rails.logger.warn "No se encontraron seeds para el evento: #{event_slug}"
    else
      Rails.logger.info "Se encontraron #{all_seeds.size} seeds para el evento: #{event_slug}"
    end
    
    all_seeds
  end
end
