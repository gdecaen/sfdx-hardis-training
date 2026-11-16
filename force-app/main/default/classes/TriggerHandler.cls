/**
 * @description Base class of the trigger framework. Every trigger delegates to a handler that extends
 * this class and overrides the context methods it needs. Provides handler bypass and a recursion guard.
 */
public virtual inherited sharing class TriggerHandler {
	private static Map<String, LoopCount> loopCountByHandler = new Map<String, LoopCount>();
	private static Set<String> bypassedHandlers = new Set<String>();

	@TestVisible
	private System.TriggerOperation context;

	@TestVisible
	private Boolean isTriggerExecuting;

	protected List<SObject> newRecords;
	protected Map<Id, SObject> newMap;
	protected List<SObject> oldRecords;
	protected Map<Id, SObject> oldMap;

	/**
	 * @description Captures the current trigger context.
	 */
	public TriggerHandler() {
		this.isTriggerExecuting = Trigger.isExecuting;
		this.context = Trigger.operationType;
	}

	/**
	 * @description Entry point called by the trigger: dispatches to the context method of the handler.
	 */
	public void run() {
		if (!this.validateRun()) {
			return;
		}
		String handlerName = this.getHandlerName();
		this.enter(handlerName);
		try {
			this.dispatch();
		} finally {
			this.leave(handlerName);
		}
	}

	/**
	 * @description Limits how many times this handler can be re-entered within the same transaction.
	 * @param max Maximum nested executions allowed
	 */
	public void setMaxLoopCount(Integer max) {
		String handlerName = this.getHandlerName();
		LoopCount loopCount = loopCountByHandler.get(handlerName);
		if (loopCount == null) {
			loopCountByHandler.put(handlerName, new LoopCount(max));
		} else {
			loopCount.max = max;
		}
	}

	/**
	 * @description Removes the recursion limit of this handler.
	 */
	public void clearMaxLoopCount() {
		loopCountByHandler.remove(this.getHandlerName());
	}

	/**
	 * @description Temporarily disables a handler.
	 * @param handlerName Class name of the handler to bypass
	 */
	public static void bypass(String handlerName) {
		bypassedHandlers.add(handlerName);
	}

	/**
	 * @description Re-enables a previously bypassed handler.
	 * @param handlerName Class name of the handler
	 */
	public static void clearBypass(String handlerName) {
		bypassedHandlers.remove(handlerName);
	}

	/**
	 * @description Checks whether a handler is bypassed.
	 * @param handlerName Class name of the handler
	 * @return True when the handler is bypassed
	 */
	public static Boolean isBypassed(String handlerName) {
		return bypassedHandlers.contains(handlerName);
	}

	/**
	 * @description Re-enables all handlers.
	 */
	public static void clearAllBypasses() {
		bypassedHandlers.clear();
	}

	@TestVisible
	protected virtual void beforeInsert() {
	}

	@TestVisible
	protected virtual void beforeUpdate() {
	}

	@TestVisible
	protected virtual void beforeDelete() {
	}

	@TestVisible
	protected virtual void afterInsert() {
	}

	@TestVisible
	protected virtual void afterUpdate() {
	}

	@TestVisible
	protected virtual void afterDelete() {
	}

	@TestVisible
	protected virtual void afterUndelete() {
	}

	@TestVisible
	private String getHandlerName() {
		return String.valueOf(this).substringBefore(':');
	}

	private Boolean validateRun() {
		if (this.isTriggerExecuting != true || this.context == null) {
			throw new TriggerHandlerException('Trigger handler called outside of a trigger execution');
		}
		return !bypassedHandlers.contains(this.getHandlerName());
	}

	private void dispatch() {
		switch on this.context {
			when BEFORE_INSERT {
				this.beforeInsert();
			}
			when BEFORE_UPDATE {
				this.beforeUpdate();
			}
			when BEFORE_DELETE {
				this.beforeDelete();
			}
			when AFTER_INSERT {
				this.afterInsert();
			}
			when AFTER_UPDATE {
				this.afterUpdate();
			}
			when AFTER_DELETE {
				this.afterDelete();
			}
			when AFTER_UNDELETE {
				this.afterUndelete();
			}
		}
	}

	private void enter(String handlerName) {
		LoopCount loopCount = loopCountByHandler.get(handlerName);
		if (loopCount == null) {
			return;
		}
		loopCount.depth++;
		if (loopCount.depth > loopCount.max) {
			loopCount.depth--;
			throw new TriggerHandlerException(
				'Maximum loop count of ' + loopCount.max + ' reached in ' + handlerName
			);
		}
	}

	private void leave(String handlerName) {
		LoopCount loopCount = loopCountByHandler.get(handlerName);
		if (loopCount != null && loopCount.depth > 0) {
			loopCount.depth--;
		}
	}

	private class LoopCount {
		private Integer max;
		private Integer depth = 0;

		private LoopCount(Integer max) {
			this.max = max;
		}
	}

	/**
	 * @description Raised when the handler is misused or exceeds its recursion limit.
	 */
	public class TriggerHandlerException extends Exception {
	}
}