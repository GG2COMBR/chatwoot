<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SpreadsheetCampaignsAPI from 'dashboard/api/spreadsheetCampaigns';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  templateVariables: {
    type: Array,
    default: () => [],
  },
});

const audienceFile = defineModel('file', {
  type: [Object, File],
  default: null,
});
const columnMapping = defineModel('mapping', {
  type: Object,
  default: () => ({}),
});
const phoneColumn = defineModel('phoneColumn', {
  type: String,
  default: '',
});

const { t } = useI18n();
const fileInput = ref(null);
const isParsing = ref(false);
const headers = ref([]);
const previewRows = ref([]);

const hasFile = computed(() => !!audienceFile.value);
const formatVariable = variable => `{{${variable}}}`;

const handleFileSelect = async event => {
  const file = event.target.files?.[0];
  if (!file) return;

  audienceFile.value = file;
  isParsing.value = true;
  try {
    const { data } = await SpreadsheetCampaignsAPI.parseCsvHeaders(file);
    headers.value = data.headers || [];
    previewRows.value = data.preview || [];

    // Auto-detect phone column
    const candidates = ['telefone', 'phone', 'celular', 'whatsapp', 'tel'];
    const matched = headers.value.find(h =>
      candidates.includes(h.toLowerCase().trim())
    );
    if (matched) {
      phoneColumn.value = matched;
    }

    // Auto-map name if present
    const nameCol = headers.value.find(h =>
      ['nome', 'name', 'cliente'].includes(h.toLowerCase().trim())
    );
    if (nameCol && props.templateVariables.length > 0) {
      columnMapping.value = {
        ...columnMapping.value,
        [props.templateVariables[0]]: nameCol,
      };
    }
  } catch (error) {
    const msg =
      error?.response?.data?.error ||
      t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.PARSE_ERROR');
    useAlert(msg);
    audienceFile.value = null;
  } finally {
    isParsing.value = false;
  }
};

const removeFile = () => {
  audienceFile.value = null;
  headers.value = [];
  previewRows.value = [];
  columnMapping.value = {};
  phoneColumn.value = '';
  if (fileInput.value) fileInput.value.value = '';
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div
      v-if="!hasFile"
      class="flex flex-col items-center justify-center p-6 border-2 border-dashed rounded-lg border-n-weak hover:border-n-brand bg-n-surface-1 cursor-pointer"
      @click="fileInput?.click()"
    >
      <input
        ref="fileInput"
        type="file"
        accept=".csv"
        class="hidden"
        @change="handleFileSelect"
      />
      <Icon icon="i-lucide-upload-cloud" class="size-8 text-n-slate-10 mb-2" />
      <p class="text-body-main font-medium text-n-slate-12 mb-1">
        {{ t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.UPLOAD_TITLE') }}
      </p>
      <p class="text-body-small text-n-slate-11">
        {{ t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.UPLOAD_SUBTITLE') }}
      </p>
    </div>

    <div
      v-else
      class="flex flex-col gap-3 p-4 border rounded-lg border-n-weak bg-n-surface-1"
    >
      <div class="flex items-center justify-between">
        <div class="flex items-center gap-2">
          <Icon icon="i-lucide-file-spreadsheet" class="size-5 text-n-brand" />
          <span class="text-body-main font-medium text-n-slate-12">
            {{ audienceFile?.name }}
          </span>
          <span
            v-if="previewRows.length"
            class="text-body-small px-2 py-0.5 rounded bg-n-alpha-2 text-n-slate-11"
          >
            {{
              t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.DETECTED_COLUMNS', {
                count: headers.length,
              })
            }}
          </span>
        </div>
        <Button
          variant="ghost"
          color="slate"
          size="sm"
          icon="i-lucide-trash"
          @click="removeFile"
        />
      </div>

      <div class="flex flex-col gap-3 pt-3 border-t border-n-weak">
        <div class="flex flex-col gap-1.5">
          <label class="text-subheading text-n-slate-12">
            {{ t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.PHONE_COLUMN_LABEL') }}
          </label>
          <select
            v-model="phoneColumn"
            class="w-full px-3 py-2 text-body-main border rounded-md border-n-weak bg-n-surface-1 text-n-slate-12"
          >
            <option value="" disabled>
              {{ t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.SELECT_COLUMN') }}
            </option>
            <option v-for="header in headers" :key="header" :value="header">
              {{ header }}
            </option>
          </select>
        </div>

        <div v-if="templateVariables.length" class="flex flex-col gap-2 pt-2">
          <p class="text-subheading text-n-slate-12">
            {{ t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.VARIABLES_MAPPING') }}
          </p>
          <div
            v-for="variable in templateVariables"
            :key="variable"
            class="flex items-center justify-between gap-3"
          >
            <span
              class="text-body-main text-n-slate-11 font-mono text-xs px-2 py-1 bg-n-alpha-2 rounded"
            >
              {{ formatVariable(variable) }}
            </span>
            <select
              v-model="columnMapping[variable]"
              class="flex-1 px-3 py-1.5 text-body-main border rounded-md border-n-weak bg-n-surface-1 text-n-slate-12"
            >
              <option value="">
                {{ t('CAMPAIGN.WHATSAPP.FORM.SPREADSHEET.SELECT_COLUMN') }}
              </option>
              <option v-for="header in headers" :key="header" :value="header">
                {{ header }}
              </option>
            </select>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
