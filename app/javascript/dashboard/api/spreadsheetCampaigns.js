/* global axios */

import ApiClient from './ApiClient';

class SpreadsheetCampaignsAPI extends ApiClient {
  constructor() {
    super('spreadsheet_campaigns', { accountScoped: true });
  }

  parseCsvHeaders(file) {
    const formData = new FormData();
    formData.append('file', file);
    return axios.post(`${this.url}/parse_csv_headers`, formData, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
  }

  sendTest({ inboxId, phoneNumber, templateParams }) {
    return axios.post(`${this.url}/send_test`, {
      inbox_id: inboxId,
      phone_number: phoneNumber,
      template_params: templateParams,
    });
  }

  retryFailed(campaignId) {
    return axios.post(`${this.url}/retry_failed`, {
      campaign_id: campaignId,
    });
  }

  getRecipients(campaignId, { status, page } = {}) {
    return axios.get(`${this.url}/recipients`, {
      params: { campaign_id: campaignId, status, page },
    });
  }
}

export default new SpreadsheetCampaignsAPI();
