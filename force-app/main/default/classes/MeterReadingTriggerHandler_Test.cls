@isTest
private class MeterReadingTriggerHandler_Test {
	@testSetup
	static void makeData() {
		System.runAs(TestDataFactory.insertHeliosUser()) {
			Account acc = TestDataFactory.createAccount('Test_Account_1');
			insert acc;
			insert TestDataFactory.createMeter(acc.Id, 'Test_Meter_Main');
		}
	}

	@isTest
	static void shouldUpdateMeterWhenReadingInserted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter();

			Test.startTest();
			insert TestDataFactory.createReading(meter.Id, Date.today(), 77);
			Test.stopTest();

			Assert.areEqual(77, getMeter().Last_Reading_Value__c, 'The handler should call the service after insert');
		}
	}

	@isTest
	static void shouldNotUpdateMeterWhenHandlerBypassed() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter();

			Test.startTest();
			TriggerHandler.bypass('MeterReadingTriggerHandler');
			insert TestDataFactory.createReading(meter.Id, Date.today(), 77);
			TriggerHandler.clearAllBypasses();
			Test.stopTest();

			Assert.isNull(getMeter().Last_Reading_Value__c, 'A bypassed handler should not update the meter');
		}
	}

	@isTest
	static void shouldProcessEveryChunkWhenMoreThan200ReadingsInserted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter();
			List<Meter_Reading__c> readings = TestDataFactory.createReadings(meter.Id, Date.today().addDays(-300), 251);

			Test.startTest();
			insert readings;
			Test.stopTest();

			Assert.areEqual(
				Date.today().addDays(-50),
				getMeter().Last_Reading_Date__c,
				'The latest of 251 readings should be copied to the meter'
			);
		}
	}

	@isTest
	static void shouldRunWithoutErrorWhenReadingsUpdatedDeletedAndUndeleted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter();
			Meter_Reading__c reading = TestDataFactory.createReading(meter.Id, Date.today(), 10);
			insert reading;

			Test.startTest();
			reading.Value__c = 20;
			update reading;
			delete reading;
			undelete reading;
			Test.stopTest();

			Assert.areEqual(
				1,
				[SELECT COUNT() FROM Meter_Reading__c WHERE Meter__c = :meter.Id],
				'Update, delete and undelete should run through the handler without error'
			);
		}
	}

	private static Meter__c getMeter() {
		return [
			SELECT Id, Last_Reading_Date__c, Last_Reading_Value__c
			FROM Meter__c
			WHERE Serial_Number__c = 'Test_Meter_Main'
			LIMIT 1
		];
	}
}