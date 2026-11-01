import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import KanbanCard from '../KanbanCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

describe('KanbanCard.vue', () => {
  const cardMock = {
    id: 1,
    title: 'Implante Dentário',
    value: 3500.0,
    priority: 'high',
    status: 'open',
    contact: {
      id: 10,
      name: 'João da Silva',
      phone_number: '+5511999999999',
    },
    conversation: {
      id: 20,
      display_id: 101,
      status: 'open',
    },
    assignees: [{ id: 5, name: 'Dra. Bruna' }],
  };

  it('renders card title, contact and value correctly', () => {
    const wrapper = mount(KanbanCard, {
      props: { card: cardMock },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    expect(wrapper.text()).toContain('Implante Dentário');
    expect(wrapper.text()).toContain('João da Silva');
    expect(wrapper.text()).toContain('#101');
  });

  it('emits click event when clicked', async () => {
    const wrapper = mount(KanbanCard, {
      props: { card: cardMock },
      global: {
        mocks: {
          $t: key => key,
        },
      },
    });

    await wrapper.trigger('click');
    expect(wrapper.emitted('click')).toBeTruthy();
    expect(wrapper.emitted('click')[0][0]).toEqual(cardMock);
  });
});
