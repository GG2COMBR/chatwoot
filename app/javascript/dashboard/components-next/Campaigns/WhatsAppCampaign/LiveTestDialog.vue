<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import SpreadsheetCampaignsAPI from 'dashboard/api/spreadsheetCampaigns';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  inboxId: {
    type: Number,
    required: true,
  },
  templateParams: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close']);

const { t } = useI18n();
const phoneNumber = ref('');
const isLoading = ref(false);

const handleSendTest = async () => {
  if (!phoneNumber.value.trim()) return;

  isLoading.value = true;
  try {
    const { data } = await SpreadsheetCampaignsAPI.sendTest({
      inboxId: props.inboxId,
      phoneNumber: phoneNumber.value.trim(),
      templateParams: props.templateParams,
    });

    if (data.success) {
      useAlert(t('CAMPAIGN.WHATSAPP.FORM.LIVE_TEST_SUCCESS'));
      emit('close');
    } else {
      useAlert(data.error || t('CAMPAIGN.WHATSAPP.FORM.LIVE_TEST_ERROR'));
    }
  } catch (error) {
    const errorMsg =
      error?.response?.data?.error ||
      t('CAMPAIGN.WHATSAPP.FORM.LIVE_TEST_ERROR');
    useAlert(errorMsg);
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <Dialog
    :title="t('CAMPAIGN.WHATSAPP.FORM.LIVE_TEST_TITLE')"
    :description="t('CAMPAIGN.WHATSAPP.FORM.LIVE_TEST_DESC')"
    :confirm-button-label="t('CAMPAIGN.WHATSAPP.FORM.SEND_TEST_BUTTON')"
    :cancel-button-label="t('CAMPAIGN.WHATSAPP.FORM.SCHEDULE_POPOVER.CANCEL')"
    :is-loading="isLoading"
    :disable-confirm-button="!phoneNumber.trim() || isLoading"
    @confirm="handleSendTest"
    @close="emit('close')"
  >
    <div class="flex flex-col gap-4 py-2">
      <div class="flex flex-col gap-1.5">
        <label for="test-phone" class="text-subheading text-n-slate-12">
          {{ t('CAMPAIGN.WHATSAPP.FORM.TEST_PHONE_LABEL') }}
        </label>
        <input
          id="test-phone"
          v-model="phoneNumber"
          type="text"
          class="w-full px-3 py-2 text-body-main border rounded-md border-n-weak focus:border-n-brand focus:outline-none bg-n-surface-1 text-n-slate-12"
          :placeholder="t('CAMPAIGN.WHATSAPP.FORM.TEST_PHONE_PLACEHOLDER')"
        />
        <p class="text-body-small text-n-slate-11">
          {{ t('CAMPAIGN.WHATSAPP.FORM.TEST_PHONE_HINT') }}
        </p>
      </div>
    </div>
  </Dialog>
</template>
