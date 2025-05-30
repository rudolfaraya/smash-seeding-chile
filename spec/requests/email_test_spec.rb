require 'rails_helper'

RSpec.describe "EmailTests", type: :request do
  describe "GET /send_test" do
    it "returns http success" do
      get "/email_test/send_test"
      expect(response).to have_http_status(:success)
    end
  end

end
