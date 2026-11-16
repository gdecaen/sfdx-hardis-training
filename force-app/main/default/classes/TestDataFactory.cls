/**
 * @description Test data builders of the Helios Energy data model. Methods return records without inserting them.
 */
@isTest
public with sharing class TestDataFactory {
	public static final String MINIMUM_ACCESS_PROFILE = 'Minimum Access - Salesforce';
	public static final String STANDARD_USER_PROFILE = 'Standard User';
	public static final String PLATFORM_USER_PROFILE = 'Standard Platform User';
	public static final String HELIOS_PERMISSION_SET = 'Helios_Energy_User';
	public static final String HELIOS_USER_LAST_NAME = 'Test_User_Helios';
	public static final String HELIOS_NO_FLAG_USER_LAST_NAME = 'Test_User_Helios_No_Flag';
	public static final String HELIOS_FORMER_OWNER_LAST_NAME = 'Test_User_Former_Owner';

	/**
	 * @description Inserts a Standard User holding a copy of the Helios_Energy_User grants.
	 * The grants are copied onto a permission set owned by the test, because a shipped permission set
	 * assigned in a check-only deployment does not reach the user's effective permissions.
	 * @return The inserted user, named HELIOS_USER_LAST_NAME
	 */
	public static User insertHeliosUser() {
		return insertHeliosUser(HELIOS_USER_LAST_NAME, null);
	}

	/**
	 * @description Inserts a Standard User holding a copy of the Helios_Energy_User grants, except the field
	 * permission of one field. Used to prove that a user who can save readings but cannot read a computed field
	 * is not blocked by it.
	 * @param lastName Last name of the user
	 * @param excludedField Field API name (Object.Field) whose permission is not copied, or null to copy all
	 * @return The inserted user
	 */
	public static User insertHeliosUser(String lastName, String excludedField) {
		return insertUserWithHeliosGrants(STANDARD_USER_PROFILE, lastName, excludedField);
	}

	/**
	 * @description Inserts a user of the given profile holding a copy of the Helios_Energy_User grants.
	 * @param profileName Profile name, e.g. STANDARD_USER_PROFILE
	 * @param lastName Last name of the user
	 * @return The inserted user
	 */
	public static User insertUserWithHeliosGrants(String profileName, String lastName) {
		return insertUserWithHeliosGrants(profileName, lastName, null);
	}

	private static User insertUserWithHeliosGrants(String profileName, String lastName, String excludedField) {
		User heliosUser = createUser(profileName, lastName);
		insert heliosUser;

		PermissionSet grants = new PermissionSet(
			Name = 'Test_Helios_Grants_' + Math.abs(Crypto.getRandomInteger()),
			Label = 'Test Helios Grants ' + lastName
		);
		insert grants;

		List<ObjectPermissions> objectGrants = new List<ObjectPermissions>();
		for (ObjectPermissions source : [
			SELECT SobjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete
			FROM ObjectPermissions
			WHERE Parent.Name = :HELIOS_PERMISSION_SET
			LIMIT 200
		]) {
			objectGrants.add(
				new ObjectPermissions(
					ParentId = grants.Id,
					SobjectType = source.SobjectType,
					PermissionsRead = source.PermissionsRead,
					PermissionsCreate = source.PermissionsCreate,
					PermissionsEdit = source.PermissionsEdit,
					PermissionsDelete = source.PermissionsDelete
				)
			);
		}
		insert objectGrants;

		List<FieldPermissions> fieldGrants = new List<FieldPermissions>();
		for (FieldPermissions source : [
			SELECT SobjectType, Field, PermissionsRead, PermissionsEdit
			FROM FieldPermissions
			WHERE Parent.Name = :HELIOS_PERMISSION_SET AND Field != :excludedField
			LIMIT 1000
		]) {
			fieldGrants.add(
				new FieldPermissions(
					ParentId = grants.Id,
					SobjectType = source.SobjectType,
					Field = source.Field,
					PermissionsRead = source.PermissionsRead,
					PermissionsEdit = source.PermissionsEdit
				)
			);
		}
		insert fieldGrants;

		insert new PermissionSetAssignment(AssigneeId = heliosUser.Id, PermissionSetId = grants.Id);
		return heliosUser;
	}

	/**
	 * @description Returns the user inserted by insertHeliosUser.
	 * @return The Helios test user
	 */
	public static User getHeliosUser() {
		return [SELECT Id FROM User WHERE LastName = :HELIOS_USER_LAST_NAME LIMIT 1];
	}

	/**
	 * @description Returns the user inserted by insertHeliosUser(HELIOS_NO_FLAG_USER_LAST_NAME, field).
	 * @return The Helios test user without the read access of one field
	 */
	public static User getHeliosUserWithoutFlag() {
		return [SELECT Id FROM User WHERE LastName = :HELIOS_NO_FLAG_USER_LAST_NAME LIMIT 1];
	}

	/**
	 * @description Builds an Account.
	 * @param name Account name, e.g. Test_Account_1
	 * @return The Account, not inserted
	 */
	public static Account createAccount(String name) {
		return new Account(Name = name);
	}

	/**
	 * @description Builds an electricity Meter__c.
	 * @param accountId Parent Account Id
	 * @param serialNumber Unique serial number
	 * @return The Meter__c, not inserted
	 */
	public static Meter__c createMeter(Id accountId, String serialNumber) {
		return new Meter__c(Account__c = accountId, Serial_Number__c = serialNumber, Meter_Type__c = 'Electricity');
	}

	/**
	 * @description Builds several meters for the same account.
	 * @param accountId Parent Account Id
	 * @param serialPrefix Prefix of the generated serial numbers
	 * @param count Number of meters
	 * @return The meters, not inserted
	 */
	public static List<Meter__c> createMeters(Id accountId, String serialPrefix, Integer count) {
		List<Meter__c> meters = new List<Meter__c>();
		for (Integer i = 1; i <= count; i++) {
			meters.add(createMeter(accountId, serialPrefix + i));
		}
		return meters;
	}

	/**
	 * @description Builds a manual Meter_Reading__c.
	 * @param meterId Parent Meter__c Id
	 * @param readingDate Reading date
	 * @param value Index value
	 * @return The reading, not inserted
	 */
	public static Meter_Reading__c createReading(Id meterId, Date readingDate, Decimal value) {
		return new Meter_Reading__c(
			Meter__c = meterId,
			Reading_Date__c = readingDate,
			Value__c = value,
			Source__c = MeterReadingConstants.SOURCE_MANUAL
		);
	}

	/**
	 * @description Builds consecutive daily readings for a meter, the last one dated startDate + count - 1.
	 * @param meterId Parent Meter__c Id
	 * @param startDate Date of the first reading
	 * @param count Number of readings
	 * @return The readings, not inserted, with values 1000, 1010, 1020...
	 */
	public static List<Meter_Reading__c> createReadings(Id meterId, Date startDate, Integer count) {
		List<Meter_Reading__c> readings = new List<Meter_Reading__c>();
		for (Integer i = 0; i < count; i++) {
			readings.add(createReading(meterId, startDate.addDays(i), 1000 + i * 10));
		}
		return readings;
	}

	/**
	 * @description Builds consecutive daily manual readings for a meter with the given index values.
	 * @param meterId Parent Meter__c Id
	 * @param startDate Date of the first reading
	 * @param values Index values, one reading per value, oldest first
	 * @return The readings, not inserted, dated startDate, startDate + 1...
	 */
	public static List<Meter_Reading__c> createReadingSeries(Id meterId, Date startDate, List<Decimal> values) {
		List<Meter_Reading__c> readings = new List<Meter_Reading__c>();
		for (Integer i = 0; i < values.size(); i++) {
			readings.add(createReading(meterId, startDate.addDays(i), values[i]));
		}
		return readings;
	}

	/**
	 * @description Builds a draft Energy_Contract__c.
	 * @param name Contract name
	 * @param accountId Account Id
	 * @param meterId Meter__c Id
	 * @return The contract, not inserted
	 */
	public static Energy_Contract__c createEnergyContract(String name, Id accountId, Id meterId) {
		return new Energy_Contract__c(
			Name = name,
			Account__c = accountId,
			Meter__c = meterId,
			Start_Date__c = Date.today(),
			End_Date__c = Date.today().addYears(1),
			Monthly_Consumption_kWh__c = 350,
			Status__c = 'Draft'
		);
	}

	/**
	 * @description Builds a user with the given profile.
	 * @param profileName Profile name
	 * @param lastName Last name, e.g. Test_User_Restricted
	 * @return The user, not inserted
	 */
	public static User createUser(String profileName, String lastName) {
		Profile userProfile = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
		String uniqueKey = String.valueOf(Math.abs(Crypto.getRandomInteger()));
		return new User(
			LastName = lastName,
			Alias = 'tu' + uniqueKey.left(6),
			Email = lastName.toLowerCase() + '@helios-training.demo',
			Username = lastName.toLowerCase() + '.' + uniqueKey + '@helios-training.demo',
			ProfileId = userProfile.Id,
			EmailEncodingKey = 'UTF-8',
			LanguageLocaleKey = 'en_US',
			LocaleSidKey = 'en_US',
			TimeZoneSidKey = 'Europe/Paris'
		);
	}
}