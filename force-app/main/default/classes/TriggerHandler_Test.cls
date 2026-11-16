@isTest
private class TriggerHandler_Test {
	private static List<String> calledContexts = new List<String>();

	@testSetup
	static void makeData() {
		System.runAs(TestDataFactory.insertHeliosUser()) {
			Account acc = TestDataFactory.createAccount('Test_Account_1');
			insert acc;
			insert TestDataFactory.createMeter(acc.Id, 'Test_Meter_Main');
		}
	}

	@isTest
	static void shouldDispatchEveryContextWhenRunInEachTriggerOperation() {
		Test.startTest();
		for (System.TriggerOperation operation : System.TriggerOperation.values()) {
			fakeHandler(operation).run();
		}
		Test.stopTest();

		Assert.areEqual(
			new Set<String>{
				'beforeInsert',
				'beforeUpdate',
				'beforeDelete',
				'afterInsert',
				'afterUpdate',
				'afterDelete',
				'afterUndelete'
			},
			new Set<String>(calledContexts),
			'Each trigger operation should call its matching context method'
		);
		Assert.areEqual(7, calledContexts.size(), 'Each context method should run exactly once');
	}

	@isTest
	static void shouldSkipHandlerWhenHandlerIsBypassed() {
		FakeHandler handler = fakeHandler(System.TriggerOperation.AFTER_INSERT);
		String handlerName = handler.getHandlerName();

		Test.startTest();
		TriggerHandler.bypass(handlerName);
		Boolean bypassedState = TriggerHandler.isBypassed(handlerName);
		handler.run();
		TriggerHandler.clearBypass(handlerName);
		handler.run();
		TriggerHandler.bypass(handlerName);
		TriggerHandler.clearAllBypasses();
		Boolean clearedState = TriggerHandler.isBypassed(handlerName);
		Test.stopTest();

		Assert.isTrue(bypassedState, 'Handler should be reported as bypassed');
		Assert.isFalse(clearedState, 'clearAllBypasses should re-enable the handler');
		Assert.areEqual(1, calledContexts.size(), 'Only the run after clearBypass should execute');
	}

	@isTest
	static void shouldThrowWhenCalledOutsideTrigger() {
		FakeHandler handler = new FakeHandler();
		TriggerHandler.TriggerHandlerException caught;

		Test.startTest();
		try {
			handler.run();
		} catch (TriggerHandler.TriggerHandlerException e) {
			caught = e;
		}
		Test.stopTest();

		Assert.isNotNull(caught, 'Running a handler outside a trigger should throw');
		Assert.isTrue(calledContexts.isEmpty(), 'No context method should run outside a trigger');
	}

	@isTest
	static void shouldThrowWhenMaxLoopCountExceeded() {
		FakeHandler handler = fakeHandler(System.TriggerOperation.AFTER_INSERT);
		handler.recurse = true;
		handler.setMaxLoopCount(3);
		handler.setMaxLoopCount(1);
		TriggerHandler.TriggerHandlerException caught;

		Test.startTest();
		try {
			handler.run();
		} catch (TriggerHandler.TriggerHandlerException e) {
			caught = e;
		}
		Test.stopTest();

		Assert.isNotNull(caught, 'A recursive execution above the max loop count should throw');
		Assert.isTrue(caught.getMessage().contains('Maximum loop count of 1'), 'Message should state the limit');
	}

	@isTest
	static void shouldAllowSequentialRunsWhenBelowMaxLoopCount() {
		FakeHandler handler = fakeHandler(System.TriggerOperation.AFTER_INSERT);
		handler.setMaxLoopCount(1);

		Test.startTest();
		handler.run();
		handler.run();
		handler.clearMaxLoopCount();
		handler.recurse = true;
		handler.maxRecursion = 5;
		handler.run();
		Test.stopTest();

		Assert.areEqual(5, calledContexts.size(), 'Sequential runs and unlimited recursion should all execute');
	}

	@isTest
	static void shouldRunWithoutErrorWhenFiredByRealTrigger() {
		System.runAs(TestDataFactory.getHeliosUser()) {
			Meter__c meter = [SELECT Id FROM Meter__c WHERE Serial_Number__c = 'Test_Meter_Main' LIMIT 1];

			Test.startTest();
			insert TestDataFactory.createReading(meter.Id, Date.today(), 42);
			Test.stopTest();

			Assert.areEqual(
				1,
				[SELECT COUNT() FROM Meter_Reading__c WHERE Meter__c = :meter.Id],
				'The real trigger should run the handler without error'
			);
		}
	}

	private static FakeHandler fakeHandler(System.TriggerOperation operation) {
		FakeHandler handler = new FakeHandler();
		handler.isTriggerExecuting = true;
		handler.context = operation;
		return handler;
	}

	private class FakeHandler extends TriggerHandler {
		private Boolean recurse = false;
		private Integer maxRecursion = 10;

		protected override void beforeInsert() {
			calledContexts.add('beforeInsert');
		}

		protected override void beforeUpdate() {
			calledContexts.add('beforeUpdate');
		}

		protected override void beforeDelete() {
			calledContexts.add('beforeDelete');
		}

		protected override void afterInsert() {
			calledContexts.add('afterInsert');
			if (this.recurse && calledContexts.size() < this.maxRecursion) {
				this.run();
			}
		}

		protected override void afterUpdate() {
			calledContexts.add('afterUpdate');
		}

		protected override void afterDelete() {
			calledContexts.add('afterDelete');
		}

		protected override void afterUndelete() {
			calledContexts.add('afterUndelete');
		}
	}
}