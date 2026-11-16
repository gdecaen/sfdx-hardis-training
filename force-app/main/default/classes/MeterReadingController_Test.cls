@isTest
private class MeterReadingController_Test {
	private static final Date BASE_DATE = Date.newInstance(2026, 1, 1);

	@testSetup
	static void makeData() {
		insert TestDataFactory.createUser(TestDataFactory.MINIMUM_ACCESS_PROFILE, 'Test_User_Restricted');
		System.runAs(TestDataFactory.insertHeliosUser()) {
			Account acc = TestDataFactory.createAccount('Test_Account_1');
			insert acc;
			List<Meter__c> meters = new List<Meter__c>{
				TestDataFactory.createMeter(acc.Id, 'Test_Meter_Main'),
				TestDataFactory.createMeter(acc.Id, 'Test_Meter_Empty')
			};
			insert meters;
			insert TestDataFactory.createReadings(meters[0].Id, BASE_DATE, 251);
		}
	}

	@isTest
	static void shouldReturnTenLatestReadings_WhenMeterHasMoreReadings() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Id meterId = getMeterId('Test_Meter_Main');

			Test.startTest();
			List<Meter_Reading__c> readings = MeterReadingController.getRecentReadings(meterId);
			Test.stopTest();

			Assert.areEqual(10, readings.size(), 'Only the last 10 readings should be returned');
			Assert.areEqual(BASE_DATE.addDays(250), readings[0].Reading_Date__c, 'The newest reading should come first');
		}
	}

	@isTest
	static void shouldReturnEmptyList_WhenMeterIdIsNullOrHasNoReading() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Id emptyMeterId = getMeterId('Test_Meter_Empty');

			Test.startTest();
			List<Meter_Reading__c> fromNull = MeterReadingController.getRecentReadings(null);
			List<Meter_Reading__c> fromEmpty = MeterReadingController.getRecentReadings(emptyMeterId);
			Test.stopTest();

			Assert.isTrue(fromNull.isEmpty(), 'A null meter id should return an empty list');
			Assert.isTrue(fromEmpty.isEmpty(), 'A meter without readings should return an empty list');
		}
	}

	@isTest
	static void shouldThrowAuraHandledException_WhenUserCannotReadReadings() {
		Id meterId = getMeterId('Test_Meter_Main');
		User restrictedUser = [SELECT Id FROM User WHERE LastName = 'Test_User_Restricted' LIMIT 1];
		AuraHandledException caught;

		Test.startTest();
		System.runAs(restrictedUser) {
			try {
				MeterReadingController.getRecentReadings(meterId);
			} catch (AuraHandledException e) {
				caught = e;
			}
		}
		Test.stopTest();

		Assert.isNotNull(caught, 'A user without access to readings should get an AuraHandledException');
	}

	private static Id getMeterId(String serialNumber) {
		return [SELECT Id FROM Meter__c WHERE Serial_Number__c = :serialNumber LIMIT 1].Id;
	}
}