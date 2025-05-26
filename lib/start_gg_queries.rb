# videogameIds: [1386] -> smash ultimate
# countryCode: "CL" -> Chile
module StartGgQueries
  TOURNAMENTS_QUERY = <<~GRAPHQL
    query TournamentsInChile($perPage: Int, $page: Int) {
      tournaments(query: {
        perPage: $perPage
        page: $page
        filter: { countryCode: "CL", videogameIds: [1386] }
      }) {
        nodes {
          id
          name
          slug
          startAt
          endAt
          venueAddress
        }
        pageInfo { total totalPages }
      }
    }
  GRAPHQL

  # Consulta optimizada para obtener solo torneos posteriores a una fecha específica
  TOURNAMENTS_SINCE_DATE_QUERY = <<~GRAPHQL
    query TournamentsInChileSinceDate($perPage: Int, $page: Int, $afterDate: Timestamp) {
      tournaments(query: {
        perPage: $perPage
        page: $page
        filter: { 
          countryCode: "CL", 
          videogameIds: [1386],
          afterDate: $afterDate
        }
      }) {
        nodes {
          id
          name
          slug
          startAt
          endAt
          venueAddress
        }
        pageInfo { total totalPages }
      }
    }
  GRAPHQL

  EVENTS_QUERY = <<~GRAPHQL
    query TournamentEvents($tournamentSlug: String!) {
      tournament(slug: $tournamentSlug) {
        id
        name
        events {
          id
          name
          slug
        }
      }
    }
  GRAPHQL

  EVENT_PARTICIPANTS_QUERY = <<~GRAPHQL
    query EventParticipants($tournamentSlug: String!, $eventSlug: String!, $perPage: Int, $page: Int) {
      tournament(slug: $tournamentSlug) {
        id
        name
        events(filter: { slug: $eventSlug }) {
          id
          name
          phases {
            id
            name
            phaseGroups(query: { perPage: $perPage, page: $page }) {
              nodes {
                id
                displayIdentifier
                seeds(query: { perPage: 100 }) {
            nodes {
              id
              seedNum
              entrant {
                id
                name
                participants {
                  player {
                    id
                    user {
                      id
                      slug
                      name
                      discriminator
                            bio
                            birthday
                            genderPronoun
                            location {
                              city
                              state
                              country
                            }
                      authorizations(types: [TWITTER]) { externalUsername }
                    }
                        }
                      }
                    }
                  }
                }
              }
              pageInfo {
                total
                totalPages
              }
            }
          }
        }
      }
    }
  GRAPHQL

  # Consulta alternativa que obtiene seeds directamente a través de entrants
  EVENT_SEEDING_QUERY = <<~GRAPHQL
    query EventSeeding($tournamentSlug: String!, $eventSlug: String!, $perPage: Int, $page: Int) {
      tournament(slug: $tournamentSlug) {
        id
        name
        events(filter: { slug: $eventSlug }) {
          id
          name
          entrants(query: { perPage: $perPage, page: $page }) {
            nodes {
              id
              name
              initialSeedNum
              participants {
                player {
                  id
                  user {
                    id
                    slug
                    name
                    discriminator
                    bio
                    birthday
                    genderPronoun
                    location {
                      city
                      state
                      country
                    }
                    authorizations(types: [TWITTER]) { externalUsername }
                  }
                }
              }
            }
            pageInfo {
              total
              totalPages
            }
          }
        }
      }
    }
  GRAPHQL

  # Query para obtener información de un usuario específico por ID
  USER_BY_ID_QUERY = <<~GRAPHQL
    query UserById($userId: ID!) {
      user(id: $userId) {
        id
        slug
        name
        discriminator
        bio
        birthday
        genderPronoun
        location {
          city
          state
          country
        }
        authorizations(types: [TWITTER]) {
          type
          externalUsername
        }
      }
    }
  GRAPHQL

  # Query para obtener las participaciones recientes de un usuario y extraer su tag actual
  USER_RECENT_ENTRANTS_QUERY = <<~GRAPHQL
    query UserRecentEntrants($userId: ID!) {
      user(id: $userId) {
        id
        player {
          id
          recentStandings(limit: 10) {
            entrant {
              id
              name
              participants {
                player {
                  id
                }
              }
            }
            placement
            tournament {
              id
              name
              startAt
            }
          }
        }
      }
    }
  GRAPHQL

  def self.fetch_tournaments(client, per_page = 25)
    tournaments = []
    page = 1
    total_pages = nil

    loop do
      variables = { perPage: 25, page: page }
      begin
        response = client.query(TOURNAMENTS_QUERY, variables, "TournamentsInChile")
        data = response["data"]["tournaments"]

        tournaments.concat(data["nodes"]) unless data["nodes"].nil?
        total_pages ||= data["pageInfo"]["totalPages"]
      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          Rails.logger.warn "Rate limit excedido para página #{page}. Esperando 60 segundos..."
          sleep(60)
          next
        else
          Rails.logger.error "Error en la página #{page}: #{e.message}"
          raise
        end
      end
      break if page >= total_pages
      page += 1
      sleep 2 # Aumenta el retraso
    end
    tournaments
  end

  # Método optimizado para obtener solo torneos posteriores a una fecha específica
  def self.fetch_tournaments_since_date(client, since_date, per_page = 25)
    Rails.logger.info "🔍 Buscando torneos desde: #{since_date}"
    tournaments = []
    page = 1
    total_pages = nil
    
    # Convertir la fecha a timestamp Unix para la API
    after_date_timestamp = since_date ? since_date.to_i : nil

    loop do
      variables = { 
        perPage: per_page, 
        page: page,
        afterDate: after_date_timestamp
      }
      
      begin
        # Intentar primero con la consulta optimizada con filtro de fecha
        response = client.query(TOURNAMENTS_SINCE_DATE_QUERY, variables, "TournamentsInChileSinceDate")
        data = response["data"]["tournaments"]

        new_tournaments = data["nodes"] || []
        tournaments.concat(new_tournaments)
        total_pages ||= data["pageInfo"]["totalPages"]
        
        Rails.logger.info "📄 Página #{page}/#{total_pages}: encontrados #{new_tournaments.length} torneos"
        
      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          Rails.logger.warn "⏱️  Rate limit excedido para página #{page}. Esperando 60 segundos..."
          sleep(60)
          next
        elsif e.response[:status] == 400 && e.response[:body]&.include?("afterDate")
          # Si la API no soporta el filtro afterDate, usar el método tradicional
          Rails.logger.warn "⚠️  API no soporta filtro afterDate, usando método tradicional"
          return fetch_tournaments_fallback(client, since_date, per_page)
        else
          Rails.logger.error "❌ Error en la página #{page}: #{e.message}"
          raise
        end
      end
      
      break if page >= total_pages
      page += 1
      sleep 1.5 # Retraso más conservador para nuevos torneos
    end
    
    Rails.logger.info "✅ Búsqueda completada: #{tournaments.length} torneos encontrados desde #{since_date}"
    tournaments
  end

  # Método de respaldo que filtra en Ruby si la API no soporta filtro de fecha
  def self.fetch_tournaments_fallback(client, since_date, per_page = 25)
    Rails.logger.info "🔄 Usando método de respaldo para filtrar por fecha"
    all_tournaments = fetch_tournaments(client, per_page)
    
    return all_tournaments unless since_date
    
    # Filtrar solo torneos posteriores a la fecha especificada
    filtered_tournaments = all_tournaments.select do |tournament_data|
      tournament_date = tournament_data["startAt"] ? Time.at(tournament_data["startAt"]) : nil
      tournament_date && tournament_date > since_date
    end
    
    Rails.logger.info "🎯 Filtrados #{filtered_tournaments.length} torneos de #{all_tournaments.length} totales"
    filtered_tournaments
  end

  def self.fetch_tournament_events(client, tournament_slug)
    response = client.query(EVENTS_QUERY, { tournamentSlug: tournament_slug }, "TournamentEvents")
    response["data"]["tournament"]["events"]
  rescue Faraday::ClientError => e
    if e.response[:status] == 429
      Rails.logger.warn "Rate limit excedido para torneo #{tournament_slug}. Esperando 60 segundos..."
      sleep(60) # Espera 60 segundos antes de reintentar
      retry
    else
      Rails.logger.error "Error en fetch_tournament_events: #{e.message}"
      raise
    end
  end

  def self.fetch_event_seeds(client, tournament_slug, event_slug, per_page = 100)
    seeds = []
    page = 1
    total_pages = nil

    loop do
      variables = { tournamentSlug: tournament_slug, eventSlug: event_slug, perPage: per_page, page: page }
      begin
        response = client.query(EVENT_PARTICIPANTS_QUERY, variables, "EventParticipants")
        data = response["data"]["tournament"]["events"].first

        if data && data["phases"]
          data["phases"].each do |phase|
            phase["phaseGroups"]["nodes"].each do |group|
              seeds.concat(group["seeds"]["nodes"]) unless group["seeds"]["nodes"].nil?
            end
          end
          total_pages ||= data["phases"].first&.dig("phaseGroups", "pageInfo", "totalPages") || 1
        end
      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          Rails.logger.warn "Rate limit excedido para página #{page}. Esperando 60 segundos..."
          sleep(60)
          next
        else
          Rails.logger.error "Error en la página #{page}: #{e.message}"
          raise
        end
      end
      break if page >= total_pages
      page += 1
      sleep 2
    end
    seeds
  end

  # Obtener información de un usuario específico por ID
  def self.fetch_user_by_id(client, user_id)
    Rails.logger.info "🔍 Obteniendo información del usuario ID: #{user_id}"
    
    begin
      variables = { userId: user_id }
      response = client.query(USER_BY_ID_QUERY, variables, "UserById")
      
      if response["data"] && response["data"]["user"]
        Rails.logger.info "✅ Información obtenida para usuario #{user_id}"
        response["data"]["user"]
      else
        Rails.logger.warn "⚠️ No se encontró información para el usuario #{user_id}"
        nil
      end
    rescue Faraday::ClientError => e
      if e.response[:status] == 429
        Rails.logger.warn "Rate limit excedido para usuario #{user_id}. Esperando 60 segundos..."
        sleep(60)
        # Reintentar una vez
        retry
      else
        Rails.logger.error "Error obteniendo información del usuario #{user_id}: #{e.message}"
        raise
      end
    rescue StandardError => e
      Rails.logger.error "Error inesperado obteniendo usuario #{user_id}: #{e.message}"
      nil
    end
  end

  # Obtener el tag más reciente del usuario desde sus participaciones
  def self.fetch_user_recent_tag(client, user_id)
    Rails.logger.info "🏷️ Obteniendo tag reciente del usuario ID: #{user_id}"
    
    begin
      variables = { userId: user_id }
      response = client.query(USER_RECENT_ENTRANTS_QUERY, variables, "UserRecentEntrants")
      
      if response["data"] && response["data"]["user"] && response["data"]["user"]["player"]
        standings = response["data"]["user"]["player"]["recentStandings"]
        
        if standings && standings.any?
          # Buscar el entrant más reciente que sea individual (solo un participante)
          recent_individual_entrant = standings.find do |standing|
            entrant = standing["entrant"]
            participants = entrant["participants"] || []
            # Solo considerar entrants individuales (un solo participante)
            participants.length == 1 && participants.first["player"]["id"].to_s == user_id.to_s
          end
          
          if recent_individual_entrant
            tag = recent_individual_entrant["entrant"]["name"]
            Rails.logger.info "✅ Tag reciente encontrado para usuario #{user_id}: #{tag}"
            return tag
          else
            Rails.logger.warn "⚠️ No se encontraron participaciones individuales recientes para usuario #{user_id}"
            return nil
          end
        else
          Rails.logger.warn "⚠️ No se encontraron participaciones recientes para usuario #{user_id}"
          return nil
        end
      else
        Rails.logger.warn "⚠️ No se encontró información de jugador para usuario #{user_id}"
        return nil
      end
    rescue Faraday::ClientError => e
      if e.response[:status] == 429
        Rails.logger.warn "Rate limit excedido para tag de usuario #{user_id}. Esperando 60 segundos..."
        sleep(60)
        # Reintentar una vez
        retry
      else
        Rails.logger.error "Error obteniendo tag del usuario #{user_id}: #{e.message}"
        return nil
      end
    rescue StandardError => e
      Rails.logger.error "Error inesperado obteniendo tag del usuario #{user_id}: #{e.message}"
      return nil
    end
  end
end
