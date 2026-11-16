@isTest
private class MeterReadingSelector_Test {
	private static final Date BASE_DATE = Date.newInstance(2026, 1, 1);

	@testSetup
	static void makeData() {
		System.runAs(TestDataFactory.insertHeliosUser()) {
			Account acc = TestDataFactory.createAccount('Test_Account_1');
			insert acc;
			Meter__c meter = TestDataFactory.createMeter(acc.Id, 'Test_Meter_Main');
			insert meter;
			insert TestDataFactory.createReadings(meter.Id, BASE_DATE, 251);
		}
	}

	@isTest
	static void shouldReturnNewestReadingsFirstWhenMeterHasReadings() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = [SELECT Id FROM Meter__c WHERE Serial_Number__c = 'Test_Meter_Main' LIMIT 1];

			Test.startTest();
			List<Meter_Reading__c> readings = MeterReadingSelector.selectRecentByMeterId(meter.Id, 5);
			Test.stopTest();

			Assert.areEqual(5, readings.size(), 'The selector should apply the limit');
			Assert.areEqual(BASE_DATE.addDays(250), readings[0].Reading_Date__c, 'The newest reading should come first');
			Assert.isTrue(readings[0].Reading_Date__c > readings[4].Reading_Date__c, 'Readings should be sorted descending');
		}
	}

	@isTest
	static void shouldReturnEmptyListWhenMeterIdIsNull() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Test.startTest();
			List<Meter_Reading__c> readings = MeterReadingSelector.selectRecentByMeterId(null, 10);
			Test.stopTest();

			Assert.isTrue(readings.isEmpty(), 'No reading should match a null meter id');
		}
	}
}