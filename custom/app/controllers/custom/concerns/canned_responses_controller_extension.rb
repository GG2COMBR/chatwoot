# frozen_string_literal: true

module Custom::Concerns::CannedResponsesControllerExtension
  def create
    ActiveRecord::Base.transaction do
      @canned_response = Current.account.canned_responses.new(canned_response_params.except(:team_ids))
      @canned_response.save!
      @canned_response.sync_teams!(params[:canned_response][:team_ids]) if params[:canned_response].key?(:team_ids)
    end
    render json: @canned_response
  end

  def update
    ActiveRecord::Base.transaction do
      @canned_response.update!(canned_response_params.except(:team_ids))
      @canned_response.sync_teams!(params[:canned_response][:team_ids]) if params[:canned_response].key?(:team_ids)
    end
    render json: @canned_response
  end

  private

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, team_ids: [])
  end

  def canned_responses
    base_scope = super
    return base_scope if Current.user&.administrator?

    user_team_ids = Current.user&.team_ids || []
    restricted_response_ids = Custom::CannedResponseTeam.where(account_id: Current.account.id).select(:canned_response_id)

    public_responses = base_scope.where.not(id: restricted_response_ids)
    return public_responses if user_team_ids.empty?

    team_response_ids = Custom::CannedResponseTeam.where(account_id: Current.account.id, team_id: user_team_ids).select(:canned_response_id)
    base_scope.where(id: public_responses.select(:id)).or(base_scope.where(id: team_response_ids))
  end
end
