@isTest
private class MeterReadingAfterSaveFlow_Test {
	@testSetup
	static void makeData() {
		System.runAs(TestDataFactory.insertHeliosUser()) {
			Account acc = TestDataFactory.createAccount('Test_Account_1');
			insert acc;
			insert new List<Meter__c>{
				TestDataFactory.createMeter(acc.Id, 'Test_Meter_Main'),
				TestDataFactory.createMeter(null, 'Test_Meter_NoAccount')
			};
		}
	}

	@isTest
	static void shouldCreateTaskForAccountOwnerWhenEstimatedReadingsInserted() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_Main');
			List<Meter_Reading__c> readings = TestDataFactory.createReadings(meter.Id, Date.today().addDays(-300), 251);
			for (Meter_Reading__c reading : readings) {
				reading.Source__c = MeterReadingConstants.SOURCE_ESTIMATED;
			}

			Test.startTest();
			insert readings;
			Test.stopTest();

			List<Task> tasks = [SELECT OwnerId, Subject FROM Task WHERE WhatId IN :readings LIMIT 500];
			Assert.areEqual(251, tasks.size(), 'One task per estimated reading should be created');
			Assert.areEqual(meter.Account__r.OwnerId, tasks[0].OwnerId, 'The task should be assigned to the account owner');
			Assert.areEqual(
				Label.Meter_Reading_Estimated_Task_Subject,
				tasks[0].Subject,
				'The task subject should come from the custom label'
			);
		}
	}

	@isTest
	static void shouldNotCreateTaskWhenReadingIsManual() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_Main');
			Meter_Reading__c reading = TestDataFactory.createReading(meter.Id, Date.today(), 10);

			Test.startTest();
			insert reading;
			Test.stopTest();

			Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :reading.Id], 'A manual reading should create no task');
		}
	}

	@isTest
	static void shouldNotCreateTaskWhenMeterHasNoAccount() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = getMeter('Test_Meter_NoAccount');
			Meter_Reading__c reading = TestDataFactory.createReading(meter.Id, Date.today(), 10);
			reading.Source__c = MeterReadingConstants.SOURCE_ESTIMATED;

			Test.startTest();
			insert reading;
			Test.stopTest();

			Assert.areEqual(0, [SELECT COUNT() FROM Task WHERE WhatId = :reading.Id], 'No task without a meter account');
		}
	}

	private static Meter__c getMeter(String serialNumber) {
		return [SELECT Id, Account__r.OwnerId FROM Meter__c WHERE Serial_Number__c = :serialNumber LIMIT 1];
	}
}