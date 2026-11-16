trigger MeterReadingTrigger on Meter_Reading__c(
	before insert,
	before update,
	before delete,
	after insert,
	after update,
	after delete,
	after undelete
) {
	if (!FeatureManagement.checkPermission(MeterReadingConstants.BYPASS_TRIGGER_PERMISSION)) {
		new MeterReadingTriggerHandler().run();
	}
}