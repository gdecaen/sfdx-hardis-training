import { LightningElement, api, wire } from 'lwc';
import getRecentReadings from '@salesforce/apex/MeterReadingController.getRecentReadings';
import TITLE_LABEL from '@salesforce/label/c.Meter_Reading_History_Title';
import EMPTY_LABEL from '@salesforce/label/c.Meter_Reading_History_Empty';
import ERROR_LABEL from '@salesforce/label/c.Meter_Reading_History_Error';
import LOADING_LABEL from '@salesforce/label/c.Meter_Reading_History_Loading';
import COLUMN_DATE_LABEL from '@salesforce/label/c.Meter_Reading_History_Column_Date';
import COLUMN_VALUE_LABEL from '@salesforce/label/c.Meter_Reading_History_Column_Value';
import COLUMN_SOURCE_LABEL from '@salesforce/label/c.Meter_Reading_History_Column_Source';

const COLUMNS = [
    { label: COLUMN_DATE_LABEL, fieldName: 'Reading_Date__c', type: 'date-local' },
    {
        label: COLUMN_VALUE_LABEL,
        fieldName: 'Value__c',
        type: 'number',
        typeAttributes: { minimumFractionDigits: 2, maximumFractionDigits: 2 }
    },
    { label: COLUMN_SOURCE_LABEL, fieldName: 'Source__c', type: 'text' }
];

export default class MeterReadingHistory extends LightningElement {
    @api recordId;

    labels = {
        title: TITLE_LABEL,
        empty: EMPTY_LABEL,
        loading: LOADING_LABEL
    };
    columns = COLUMNS;
    readings = [];
    errorMessage;
    isLoading = true;

    @wire(getRecentReadings, { meterId: '$recordId' })
    wiredReadings({ data, error }) {
        if (data) {
            this.readings = data;
            this.errorMessage = undefined;
            this.isLoading = false;
        } else if (error) {
            this.readings = [];
            this.errorMessage = error?.body?.message ?? ERROR_LABEL;
            this.isLoading = false;
        }
    }

    get hasReadings() {
        return this.readings.length > 0;
    }
}