/**
 * @description Trigger handler of Meter_Reading__c. Delegates business logic to MeterReadingService.
 */
public with sharing class MeterReadingTriggerHandler extends TriggerHandler {
	private static final Integer MAX_LOOP_COUNT = 2;

	/**
	 * @description Initialises the handler with the trigger records and the recursion guard.
	 */
	public MeterReadingTriggerHandler() {
		super();
		this.setMaxLoopCount(MAX_LOOP_COUNT);
		this.newRecords = (List<Meter_Reading__c>) Trigger.new;
		this.oldMap = (Map<Id, Meter_Reading__c>) Trigger.oldMap;
	}

	protected override void afterInsert() {
		MeterReadingService.updateMetersWithLatestReading((List<Meter_Reading__c>) this.newRecords);
	}

	protected override void afterUpdate() {
		MeterReadingService.updateMetersWithLatestReading((List<Meter_Reading__c>) this.newRecords);
	}

	protected override void afterDelete() {
		MeterReadingService.updateMetersWithLatestReading((List<Meter_Reading__c>) this.oldMap.values());
	}

	protected override void afterUndelete() {
		MeterReadingService.updateMetersWithLatestReading((List<Meter_Reading__c>) this.newRecords);
	}
}