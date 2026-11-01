/* global axios */

import ApiClient from './ApiClient';

class CampaignsAPI extends ApiClient {
  constructor() {
    super('campaigns', { accountScoped: true });
  }

  create(data) {
    if (data.audience_file instanceof File) {
      const formData = new FormData();
      Object.keys(data).forEach(key => {
        if (
          key === 'template_params' ||
          key === 'audience' ||
          key === 'trigger_rules'
        ) {
          formData.append(`campaign[${key}]`, JSON.stringify(data[key]));
        } else if (key === 'audience_file') {
          formData.append('campaign[audience_file]', data[key]);
        } else if (data[key] !== undefined && data[key] !== null) {
          formData.append(`campaign[${key}]`, data[key]);
        }
      });
      return axios.post(this.url, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });
    }
    return super.create(data);
  }

  analyticsMetrics(id) {
    return axios.get(`${this.url}/${id}/analytics/metrics`);
  }

  analyticsContacts(id, { status, page } = {}) {
    return axios.get(`${this.url}/${id}/analytics/contacts`, {
      params: { status, page },
    });
  }
}

export default new CampaignsAPI();
