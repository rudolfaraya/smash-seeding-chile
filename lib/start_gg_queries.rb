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
      begin
        response = client.query(EVENT_PARTICIPANTS_QUERY,
                              { tournamentSlug: tournament_slug, eventSlug: event_slug, perPage: per_page, page: page },
                              "EventParticipants")
        event = response["data"]["tournament"]["events"].first
        data = event["seeds"]
        seeds.concat(data["nodes"]) unless data["nodes"].nil?
        total_pages ||= data["pageInfo"]["totalPages"]
      rescue Faraday::ClientError => e
        if e.response[:status] == 429
          Rails.logger.warn "Rate limit excedido para torneo #{tournament_slug}, evento #{event_slug}, página #{page}. Esperando 60 segundos..."
          sleep(60) # Espera 60 segundos antes de reintentar
          next
        else
          Rails.logger.error "Error en fetch_event_seeds: #{e.message}"
          raise
        end
      end
      break if page >= total_pages
      page += 1
      sleep 2 # Aumenta el retraso entre páginas
    end
    seeds
  end
end
