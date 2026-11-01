import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import SpreadsheetAudienceFields from '../SpreadsheetAudienceFields.vue';
import SpreadsheetCampaignsAPI from 'dashboard/api/spreadsheetCampaigns';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('SpreadsheetAudienceFields.vue', () => {
  it('renders upload area when no file is present', () => {
    const wrapper = mount(SpreadsheetAudienceFields, {
      props: {
        file: null,
        mapping: {},
        phoneColumn: '',
        templateVariables: ['1'],
      },
    });

    expect(wrapper.text()).toContain(
      'CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.UPLOAD_TITLE'
    );
  });

  it('parses headers and auto-detects phone and name columns when file is selected', async () => {
    vi.spyOn(SpreadsheetCampaignsAPI, 'parseCsvHeaders').mockResolvedValue({
      data: {
        headers: ['Nome', 'Telefone', 'Cidade'],
        preview: [{ nome: 'Ana', telefone: '11999999999', cidade: 'SP' }],
      },
    });

    const wrapper = mount(SpreadsheetAudienceFields, {
      props: {
        file: null,
        mapping: {},
        phoneColumn: '',
        templateVariables: ['1'],
      },
    });

    const file = new File(['Nome,Telefone\nAna,11999999999'], 'leads.csv', {
      type: 'text/csv',
    });
    const input = wrapper.find('input[type="file"]');
    Object.defineProperty(input.element, 'files', {
      value: [file],
    });

    await input.trigger('change');

    expect(SpreadsheetCampaignsAPI.parseCsvHeaders).toHaveBeenCalledWith(file);
    expect(wrapper.emitted('update:file')?.[0]?.[0]).toBe(file);
    expect(wrapper.emitted('update:phoneColumn')?.[0]?.[0]).toBe('Telefone');
  });
});
