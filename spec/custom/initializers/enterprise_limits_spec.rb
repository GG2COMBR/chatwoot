# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Enterprise Limits Self-Hosted Compatibility', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  before do
    allow(ChatwootApp).to receive(:chatwoot_cloud?).and_return(false)
  end

  it 'returns 200 OK with default limits on self-hosted installations' do
    get "/enterprise/api/v1/accounts/#{account.id}/limits",
        headers: admin.create_new_auth_token,
        as: :json

    expect(response).to have_http_status(:ok)
    json = response.parsed_body
    expect(json['id']).to eq(account.id)
    expect(json['limits']).to be_present
    expect(json['limits']['agents']).to be_present
  end
end
