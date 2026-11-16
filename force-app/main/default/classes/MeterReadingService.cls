/**
 * @description Business logic of Meter_Reading__c.
 */
public with sharing class MeterReadingService {
	/**
	 * @description Copies the latest reading of each impacted meter onto the meter
	 * (Last_Reading_Date__c and Last_Reading_Value__c).
	 * (Last_Reading_Date__c and Last_Reading_Value__c), after readings are inserted, updated,
	 * deleted or undeleted. A meter left without any reading gets both fields cleared.
	 * @param readings Readings that were inserted, updated, deleted or undeleted
	 */
	public static void updateMetersWithLatestReading(List<Meter_Reading__c> readings) {
		Set<Id> meterIds = new Set<Id>();
		for (Meter_Reading__c reading : readings ?? new List<Meter_Reading__c>()) {
			if (reading.Meter__c != null) {
				meterIds.add(reading.Meter__c);
			}
		}
		if (meterIds.isEmpty()) {
			return;
		}

		List<Meter__c> meters = [
			SELECT
				Id,
				Last_Reading_Date__c,
				Last_Reading_Value__c,
				(SELECT Reading_Date__c, Value__c FROM Meter_Readings__r ORDER BY Reading_Date__c DESC, CreatedDate DESC LIMIT 1)
			FROM Meter__c
			WHERE Id IN :meterIds
			WITH USER_MODE
			LIMIT 50000
		];

		List<Meter__c> metersToUpdate = new List<Meter__c>();
		for (Meter__c meter : meters) {
			Meter_Reading__c latest = meter.Meter_Readings__r.isEmpty() ? new Meter_Reading__c() : meter.Meter_Readings__r[0];
			if (isDifferent(meter, latest)) {
				metersToUpdate.add(
					new Meter__c(
						Id = meter.Id,
						Last_Reading_Date__c = latest.Reading_Date__c,
						Last_Reading_Value__c = latest.Value__c
					)
				);
			}
		}
		Database.update(metersToUpdate, AccessLevel.USER_MODE);
	}

	private static Boolean isDifferent(Meter__c meter, Meter_Reading__c latest) {
		return meter.Last_Reading_Date__c != latest.Reading_Date__c || meter.Last_Reading_Value__c != latest.Value__c;
	}
}