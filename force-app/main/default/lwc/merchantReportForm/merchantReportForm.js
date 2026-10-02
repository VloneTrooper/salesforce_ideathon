import { LightningElement, wire } from 'lwc';
import getStorefronts from '@salesforce/apex/MerchantReportController.getStorefronts';
import submitReport from '@salesforce/apex/MerchantReportController.submitReport';

export default class MerchantReportForm extends LightningElement {
    email = '';
    storefront = '';
    message = '';
    error;
    sent = false;
    submitting = false;
    storefrontOptions = [];

    quickStarts = [
        { label: 'Out of an item', text: 'Out of ' },
        { label: 'Running late', text: 'Running late: kitchen is about 20 min behind' },
        { label: 'Courier / handoff', text: 'Courier handoff problem: ' }
    ];

    @wire(getStorefronts)
    wiredStorefronts({ data, error }) {
        if (data) {
            this.storefrontOptions = data.map((name) => ({ label: name, value: name }));
        } else if (error) {
            this.error = 'Could not load storefronts. Refresh the page and try again.';
        }
    }

    get submitLabel() {
        return this.submitting ? 'Sending…' : 'Send to Pronto Merchant Ops';
    }

    handleEmail(event) { this.email = event.target.value; }
    handleStorefront(event) { this.storefront = event.detail.value; }
    handleMessage(event) { this.message = event.target.value; }

    handleChip(event) {
        this.message = event.currentTarget.dataset.text;
        const box = this.template.querySelector('lightning-textarea');
        if (box) box.focus();
    }

    async handleSubmit() {
        this.error = undefined;
        const inputs = [...this.template.querySelectorAll('lightning-input, lightning-combobox, lightning-textarea')];
        if (!inputs.every((input) => input.reportValidity())) return;
        this.submitting = true;
        try {
            await submitReport({ email: this.email, storefront: this.storefront, message: this.message });
            this.sent = true;
            this.message = '';
        } catch (e) {
            this.error = (e && e.body && e.body.message) || 'Could not send your report. Please try again.';
        } finally {
            this.submitting = false;
        }
    }

    handleReset() {
        this.sent = false;
    }
}
