@isTest
private class MeterReadingService_Test {
	private static final Date BASE_DATE = Date.newInstance(2026, 1, 1);

	@testSetup
	static void makeData() {
		System.runAs(TestDataFactory.insertHeliosUser()) {
			Account acc = TestDataFactory.createAccount('Test_Account_1');
			insert acc;
			List<Meter__c> meters = TestDataFactory.createMeters(acc.Id, 'Test_Meter_', 3);
			insert meters;
			insert TestDataFactory.createReading(meters[0].Id, BASE_DATE, 500);
		}
	}

	@isTest
	static void shouldUpdateMeterLastReadingWhenReadingInserted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_2');

			Test.startTest();
			insert TestDataFactory.createReading(meter.Id, BASE_DATE.addDays(3), 1234.56);
			Test.stopTest();

			Meter__c result = getMeter('Test_Meter_2');
			Assert.areEqual(BASE_DATE.addDays(3), result.Last_Reading_Date__c, 'Last reading date should be copied');
			Assert.areEqual(1234.56, result.Last_Reading_Value__c, 'Last reading value should be copied');
		}
	}

	@isTest
	static void shouldRefreshMeterWhenLatestReadingUpdated() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter_Reading__c reading = [SELECT Id FROM Meter_Reading__c WHERE Meter__r.Serial_Number__c = 'Test_Meter_1' WITH USER_MODE LIMIT 1];

			Test.startTest();
			reading.Value__c = 600;
			update reading;
			Test.stopTest();

			Assert.areEqual(600, getMeter('Test_Meter_1').Last_Reading_Value__c, 'A corrected latest reading should be copied');
		}
	}

	@isTest
	static void shouldFallBackToPreviousReadingWhenLatestReadingDeleted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_1');
			Meter_Reading__c latest = TestDataFactory.createReading(meter.Id, BASE_DATE.addDays(5), 900);
			insert latest;

			Test.startTest();
			delete latest;
			Test.stopTest();

			Meter__c result = getMeter('Test_Meter_1');
			Assert.areEqual(BASE_DATE, result.Last_Reading_Date__c, 'The previous reading should become the latest');
			Assert.areEqual(500, result.Last_Reading_Value__c, 'The previous value should be copied back');
		}
	}

	@isTest
	static void shouldClearMeterWhenOnlyReadingDeletedThenRestoreWhenUndeleted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter_Reading__c reading = [SELECT Id FROM Meter_Reading__c WHERE Meter__r.Serial_Number__c = 'Test_Meter_1' WITH USER_MODE LIMIT 1];

			Test.startTest();
			delete reading;
			Meter__c cleared = getMeter('Test_Meter_1');
			undelete reading;
			Test.stopTest();

			Assert.isNull(cleared.Last_Reading_Date__c, 'A meter without readings has no last reading date');
			Assert.isNull(cleared.Last_Reading_Value__c, 'A meter without readings has no last reading value');
			Assert.areEqual(500, getMeter('Test_Meter_1').Last_Reading_Value__c, 'An undeleted reading should be the latest again');
		}
	}

	@isTest
	static void shouldKeepLatestReadingWhenOlderReadingInserted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_1');

			Test.startTest();
			insert TestDataFactory.createReading(meter.Id, BASE_DATE.addDays(-10), 100);
			Test.stopTest();

			Meter__c result = getMeter('Test_Meter_1');
			Assert.areEqual(BASE_DATE, result.Last_Reading_Date__c, 'An older reading should not replace the latest one');
			Assert.areEqual(500, result.Last_Reading_Value__c, 'Last reading value should stay the latest one');
		}
	}

	@isTest
	static void shouldDoNothingWhenReadingListIsEmptyOrNull() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Test.startTest();
			MeterReadingService.updateMetersWithLatestReading(new List<Meter_Reading__c>());
			MeterReadingService.updateMetersWithLatestReading(null);
			MeterReadingService.updateMetersWithLatestReading(new List<Meter_Reading__c>{ new Meter_Reading__c() });
			Integer queries = Limits.getQueries();
			Test.stopTest();

			Assert.areEqual(0, queries, 'No query should run when there is no meter to update');
			Assert.isNull(getMeter('Test_Meter_3').Last_Reading_Date__c, 'Meters without readings should stay empty');
		}
	}

	@isTest
	static void shouldThrowDmlExceptionWhenReadingDateIsMissing() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_3');
			DmlException caught;

			Test.startTest();
			try {
				insert TestDataFactory.createReading(meter.Id, null, 10);
			} catch (DmlException e) {
				caught = e;
			}
			Test.stopTest();

			Assert.isNotNull(caught, 'A reading without date should be rejected');
			Assert.isNull(getMeter('Test_Meter_3').Last_Reading_Date__c, 'The meter should not be updated');
		}
	}

	@isTest
	static void shouldUpdateEveryMeterWhenBulkReadingsInserted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			List<Meter__c> meters = [SELECT Id FROM Meter__c WHERE Serial_Number__c LIKE 'Test_Meter_%' LIMIT 3];
			List<Meter_Reading__c> readings = new List<Meter_Reading__c>();
			for (Meter__c meter : meters) {
				readings.addAll(TestDataFactory.createReadings(meter.Id, BASE_DATE.addDays(1), 84));
			}

			Test.startTest();
			insert readings;
			Test.stopTest();

			Assert.areEqual(252, readings.size(), 'The bulk test should cross the 200-record chunk boundary');
			for (Meter__c result : [
				SELECT Last_Reading_Date__c, Last_Reading_Value__c
				FROM Meter__c
				WHERE Id IN :meters
				LIMIT 3
			]) {
				Assert.areEqual(BASE_DATE.addDays(84), result.Last_Reading_Date__c, 'Each meter should get its latest date');
				Assert.areEqual(1830, result.Last_Reading_Value__c, 'Each meter should get its latest value');
			}
		}
	}

	private static Meter__c getMeter(String serialNumber) {
		return [
			SELECT Id, Last_Reading_Date__c, Last_Reading_Value__c
			FROM Meter__c
			WHERE Serial_Number__c = :serialNumber
			LIMIT 1
		];
	}
}