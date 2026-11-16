/**
 * @description Apex controller of the meterReadingHistory LWC.
 */
public with sharing class MeterReadingController {
	private static final Integer HISTORY_SIZE = 10;

	/**
	 * @description Returns the last readings of a meter for the reading history component.
	 * @param meterId Id of the Meter__c record
	 * @return Up to 10 readings, newest first; an empty list when meterId is null
	 */
	@AuraEnabled(cacheable=true)
	public static List<Meter_Reading__c> getRecentReadings(Id meterId) {
		if (meterId == null) {
			return new List<Meter_Reading__c>();
		}
		try {
			return MeterReadingSelector.selectRecentByMeterId(meterId, HISTORY_SIZE);
		} catch (QueryException e) {
			throw new AuraHandledException(e.getMessage());
		}
	}
}