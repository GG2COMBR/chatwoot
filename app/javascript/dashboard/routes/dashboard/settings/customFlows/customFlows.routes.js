import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';

const CustomFlowsList = () => import('./Index.vue');
const CustomFlowsEditor = () => import('./Editor.vue');

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/custom_flows'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          redirect: to => {
            return { name: 'custom_flows_list', params: to.params };
          },
        },
        {
          path: 'list',
          name: 'custom_flows_list',
          component: CustomFlowsList,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
    {
      path: frontendURL('accounts/:accountId/settings/custom_flows/:flowId/edit'),
      name: 'custom_flows_edit',
      component: CustomFlowsEditor,
      meta: {
        permissions: ['administrator'],
      },
    },
  ],
};
