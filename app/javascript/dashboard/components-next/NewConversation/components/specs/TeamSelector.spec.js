import { mount } from '@vue/test-utils';
import TeamSelector from '../TeamSelector.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const translations = {
  'COMPOSE_NEW_CONVERSATION.FORM.TEAM_SELECTOR.LABEL': 'Team:',
  'COMPOSE_NEW_CONVERSATION.FORM.TEAM_SELECTOR.BUTTON': 'Assign team',
  'COMPOSE_NEW_CONVERSATION.FORM.STATUS_SELECTOR.LABEL': 'Status:',
  'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.open.TEXT': 'Open',
  'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.pending.TEXT': 'Pending',
  'CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.snoozed.TEXT': 'Snoozed',
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => translations[key] || key,
  }),
}));

const teams = [
  { id: 1, name: 'Billing' },
  { id: 2, name: 'Support N2' },
];

const mountSelector = (props = {}) =>
  mount(TeamSelector, {
    props: {
      teams,
      selectedTeam: null,
      showTeamsDropdown: false,
      selectedStatus: 'open',
      showStatusDropdown: false,
      ...props,
    },
  });

describe('TeamSelector', () => {
  it('renders the team selector with assign team button when no team selected', () => {
    const wrapper = mountSelector();
    expect(wrapper.text()).toContain('Team:');
    expect(wrapper.text()).toContain('Assign team');
  });

  it('renders the selected team chip and emits updateTeam on remove click', async () => {
    const wrapper = mountSelector({
      selectedTeam: { id: 2, name: 'Support N2' },
    });

    expect(wrapper.text()).toContain('Support N2');
    const removeButton = wrapper.findComponent(Button);
    expect(removeButton.exists()).toBe(true);
    await removeButton.trigger('click');
    expect(wrapper.emitted('updateTeam')).toEqual([[null]]);
  });

  it('renders the status selector with default open status', () => {
    const wrapper = mountSelector({ selectedStatus: 'open' });
    expect(wrapper.text()).toContain('Status:');
    expect(wrapper.text()).toContain('Open');
  });

  it('toggles team dropdown when assign button is clicked', async () => {
    const wrapper = mountSelector();
    const assignBtn = wrapper.findComponent(Button);
    await assignBtn.trigger('click');
    expect(wrapper.emitted('toggleTeamsDropdown')).toEqual([[true]]);
  });

  it('emits updateStatus when status dropdown action is triggered', async () => {
    const wrapper = mountSelector({ showStatusDropdown: true });
    expect(wrapper.findComponent({ name: 'DropdownMenu' }).exists()).toBe(true);
    await wrapper
      .findComponent({ name: 'DropdownMenu' })
      .vm.$emit('action', { value: 'pending' });
    expect(wrapper.emitted('updateStatus')).toEqual([['pending']]);
  });
});
