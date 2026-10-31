/* global axios */
import ApiClient from './ApiClient';

class CustomFlowsAPI extends ApiClient {
  constructor() {
    super('custom_flows', { accountScoped: true });
  }

  publish(flowId) {
    return axios.post(`${this.url}/${flowId}/publish`);
  }

  duplicate(flowId) {
    return axios.post(`${this.url}/${flowId}/duplicate`);
  }
}

export default new CustomFlowsAPI();
