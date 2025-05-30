#!/bin/bash

# Start.gg API Bug Test Script
# Replace YOUR_TOKEN_HERE with your actual start.gg API token

TOKEN="0cdfea2e074c63a2da56746573c8a9e0"
API_URL="https://api.start.gg/gql/alpha"

echo "🔍 Testing start.gg API Bug - Event Seeding Mixed Results"
echo "=========================================================="

echo ""
echo "1️⃣ Getting tournament structure..."
curl -X POST $API_URL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Bug-Report-Test" \
  -d '{
    "query": "query TournamentEvents($tournamentSlug: String!) { tournament(slug: $tournamentSlug) { id name events { id name slug } } }",
    "variables": {
      "tournamentSlug": "thunderspike"
    },
    "operationName": "TournamentEvents"
  }' | jq '.'

echo ""
echo "2️⃣ Getting Singles event seeding (PROBLEMATIC QUERY)..."
curl -X POST $API_URL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Bug-Report-Test" \
  -d '{
    "query": "query EventSeedingById($eventId: ID!, $perPage: Int, $page: Int) { event(id: $eventId) { id name entrants(query: { perPage: $perPage, page: $page }) { nodes { id name initialSeedNum participants { player { id user { id slug name discriminator bio birthday genderPronoun location { city state country } authorizations(types: [TWITTER]) { externalUsername } } } } } pageInfo { total totalPages } } } }",
    "variables": {
      "eventId": "1287660",
      "perPage": 100,
      "page": 1
    },
    "operationName": "EventSeedingById"
  }' > singles_response.json

echo "Response saved to singles_response.json"

echo ""
echo "3️⃣ Getting Resurrection event seeding for comparison..."
curl -X POST $API_URL \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -H "User-Agent: Bug-Report-Test" \
  -d '{
    "query": "query EventSeedingById($eventId: ID!, $perPage: Int, $page: Int) { event(id: $eventId) { id name entrants(query: { perPage: $perPage, page: $page }) { nodes { id name initialSeedNum participants { player { id user { id slug name discriminator bio birthday genderPronoun location { city state country } authorizations(types: [TWITTER]) { externalUsername } } } } } pageInfo { total totalPages } } } }",
    "variables": {
      "eventId": "1365451",
      "perPage": 100,
      "page": 1
    },
    "operationName": "EventSeedingById"
  }' > resurrection_response.json

echo "Response saved to resurrection_response.json"

echo ""
echo "4️⃣ Analyzing seed conflicts..."

# Extract seed numbers from Singles response
echo "Singles event seed numbers:"
jq -r '.data.event.entrants.nodes[] | select(.initialSeedNum != null) | .initialSeedNum' singles_response.json | sort -n | uniq -c | sort -nr | head -20

echo ""
echo "Resurrection event seed numbers:"
jq -r '.data.event.entrants.nodes[] | select(.initialSeedNum != null) | .initialSeedNum' resurrection_response.json | sort -n | uniq -c | sort -nr | head -20

echo ""
echo "5️⃣ Summary:"
echo "Singles total entrants: $(jq '.data.event.entrants.nodes | length' singles_response.json)"
echo "Resurrection total entrants: $(jq '.data.event.entrants.nodes | length' resurrection_response.json)"

echo ""
echo "Unique seed numbers in Singles:"
jq -r '.data.event.entrants.nodes[] | select(.initialSeedNum != null) | .initialSeedNum' singles_response.json | sort -n | uniq | wc -l

echo ""
echo "Total seed entries in Singles:"
jq -r '.data.event.entrants.nodes[] | select(.initialSeedNum != null) | .initialSeedNum' singles_response.json | wc -l

echo ""
echo "🐛 BUG EVIDENCE:"
echo "If unique seeds < total seeds, there are duplicates indicating mixed event data!"

echo ""
echo "📁 Files generated:"
echo "- singles_response.json (Singles event response)"
echo "- resurrection_response.json (Resurrection event response)"
echo "- bug_report_startgg.md (Full bug report documentation)"

echo ""
echo "✅ Test completed. Send these files to start.gg support team." 
