/**
 * @description Selector of Meter_Reading__c records. All queries run in user mode.
 */
public inherited sharing class MeterReadingSelector {
	/**
	 * @description Returns the most recent readings of a meter, newest first.
	 * @param meterId Id of the parent Meter__c
	 * @param maxRecords Maximum number of readings to return
	 * @return Readings ordered by Reading_Date__c descending
	 */
	public static List<Meter_Reading__c> selectRecentByMeterId(Id meterId, Integer maxRecords) {
		return [
			SELECT Id, Name, Reading_Date__c, Value__c, Source__c
			FROM Meter_Reading__c
			WHERE Meter__c = :meterId
			WITH USER_MODE
			ORDER BY Reading_Date__c DESC, CreatedDate DESC
			LIMIT :maxRecords
		];
	}
}