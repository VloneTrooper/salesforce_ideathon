/**
 * AgentUpdateContactRecordActions
 *
 * Invocable replacement for the Update_Contact_Record flow.
 *
 * Key behaviors:
 * - Only updates fields that are provided with non-blank values (prevents overwriting with blanks/nulls).
 * - Respects sharing + CRUD/FLS using Schema describe checks and Security.stripInaccessible().
 *
 * Bulk model:
 * This is intentionally a "singleton" action: we only consider requests[0] and return a single Response row.
 */
public with sharing class AgentUpdateContactRecordActions {
    public class Request {
        @InvocableVariable(
            label='Verified Customer Id'
            description='The Contact Id for the verified customer whose profile and mailing address should be updated.'
            required=true
        )
        public String verifiedCustomerId;

        @InvocableVariable(
            label='Email'
            description='Updated email address for the contact. Leave blank if the email address should not be changed.'
            required=false
        )
        public String email;

        @InvocableVariable(
            label='Phone'
            description='Updated phone number for the contact. Leave blank if the phone number should not be changed.'
            required=false
        )
        public String phone;

        @InvocableVariable(
            label='Mailing Street'
            description='New mailing street value. Leave blank if the street should not be changed.'
            required=false
        )
        public String mailingStreet;

        @InvocableVariable(
            label='Mailing City'
            description='New mailing city value. Leave blank if the city should not be changed.'
            required=false
        )
        public String mailingCity;

        @InvocableVariable(
            label='Mailing State'
            description='New mailing state/province value. Leave blank if the state should not be changed.'
            required=false
        )
        public String mailingState;

        @InvocableVariable(
            label='Mailing Postal Code'
            description='New mailing postal/zip code value. Leave blank if the postal code should not be changed.'
            required=false
        )
        public String mailingPostalCode;

        @InvocableVariable(
            label='Mailing Country'
            description='New mailing country value. Leave blank if the country should not be changed.'
            required=false
        )
        public String mailingCountry;
    }

    public class Response {
        @InvocableVariable(
            label='Success'
            description='True when the action executed successfully. False when inputs are missing/invalid or an unexpected error occurred.'
        )
        public Boolean success;

        @InvocableVariable(
            label='Message'
            description='User-readable status message. On errors, explains what was missing or what failed.'
        )
        public String message;

        @InvocableVariable(
            label='Returned Contact'
            description='The updated Contact record with refreshed field values (limited by sharing + FLS). Null when not accessible.'
        )
        public Contact returnedContact;
    }

    @InvocableMethod(
        label='Update Contact Record'
        description='Update a verified customer’s Contact record with provided email/phone/mailing fields, ignoring blank values, and enforcing CRUD/FLS.'
    )
    public static List<Response> invoke(List<Request> requests) {
        Response out = new Response();
        out.success = false;
        out.message = null;
        out.returnedContact = null;

        Request req = (requests != null && !requests.isEmpty()) ? requests[0] : null;
        try {
            if (req == null || String.isBlank(req.verifiedCustomerId)) {
                out.message = 'verifiedCustomerId is required.';
                return new List<Response>{ out };
            }
            Id custId = Id.valueOf(req.verifiedCustomerId.trim());

            Schema.DescribeSObjectResult contactDescribe = Contact.SObjectType.getDescribe();
            if (!contactDescribe.isUpdateable()) {
                out.message = 'You do not have permission to update Contact records.';
                return new List<Response>{ out };
            }

            Contact toUpdate = new Contact(Id = custId);
            Integer requestedFieldUpdates = 0;

            if (!String.isBlank(req.email)) { toUpdate.Email = req.email.trim(); requestedFieldUpdates++; }
            if (!String.isBlank(req.phone)) { toUpdate.Phone = req.phone.trim(); requestedFieldUpdates++; }
            if (!String.isBlank(req.mailingStreet)) { toUpdate.MailingStreet = req.mailingStreet.trim(); requestedFieldUpdates++; }
            if (!String.isBlank(req.mailingCity)) { toUpdate.MailingCity = req.mailingCity.trim(); requestedFieldUpdates++; }
            if (!String.isBlank(req.mailingState)) { toUpdate.MailingState = req.mailingState.trim(); requestedFieldUpdates++; }
            if (!String.isBlank(req.mailingPostalCode)) { toUpdate.MailingPostalCode = req.mailingPostalCode.trim(); requestedFieldUpdates++; }
            if (!String.isBlank(req.mailingCountry)) { toUpdate.MailingCountry = req.mailingCountry.trim(); requestedFieldUpdates++; }

            if (requestedFieldUpdates == 0) {
                // Nothing to update; return the current record (FLS-filtered) for convenience.
                out.success = true;
                out.message = 'No changes provided.';
                out.returnedContact = safeQueryContact(custId);
                return new List<Response>{ out };
            }

            // Enforce field-level security (remove fields the running user cannot update).
            List<SObject> candidate = new List<SObject>{ toUpdate };
            SObjectAccessDecision updDecision = Security.stripInaccessible(AccessType.UPDATABLE, candidate);
            List<SObject> stripped = updDecision.getRecords();
            if (stripped.isEmpty()) {
                out.message = 'You do not have permission to update the requested Contact fields.';
                return new List<Response>{ out };
            }

            Contact strippedContact = (Contact) stripped[0];
            // If FLS stripped everything (only Id remains), skip DML.
            if (strippedContact.getPopulatedFieldsAsMap().size() <= 1) {
                out.success = false;
                out.message = 'You do not have permission to update the requested Contact fields.';
                out.returnedContact = safeQueryContact(custId);
                return new List<Response>{ out };
            }

            Database.SaveResult sr = Database.update(strippedContact, false);
            if (!sr.isSuccess()) {
                out.message = (sr.getErrors() != null && sr.getErrors().size() > 0) ? sr.getErrors()[0].getMessage() : 'Failed to update Contact.';
                return new List<Response>{ out };
            }

            out.success = true;
            out.message = 'OK';
            out.returnedContact = safeQueryContact(custId);
        } catch (Exception e) {
            out.success = false;
            out.message = e.getMessage();
        }

        return new List<Response>{ out };
    }

    private static Contact safeQueryContact(Id contactId) {
        Schema.DescribeSObjectResult d = Contact.SObjectType.getDescribe();
        if (!d.isAccessible()) return null;

        // Query only the fields the Flow previously returned.
        Contact c = [
            SELECT Id, FirstName, LastName, Email, Phone,
                   MailingStreet, MailingCity, MailingState, MailingPostalCode, MailingCountry
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];

        // Enforce read FLS on the output record.
        SObjectAccessDecision readDecision = Security.stripInaccessible(AccessType.READABLE, new List<SObject>{ c });
        if (readDecision.getRecords().isEmpty()) return null;
        return (Contact) readDecision.getRecords()[0];
    }
}