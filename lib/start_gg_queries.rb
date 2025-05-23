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
