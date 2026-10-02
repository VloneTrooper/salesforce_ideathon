// Creates the Pronto Merchant Ops inbox user (prontosupport2@gmail.com) and makes Ethan Skinner an admin.
// Both get: System Administrator, Service Cloud User, Pronto_Ideathon_Access, Merchant Ops + Agent Escalations queues.
Id adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator'].Id;
User valen = [SELECT TimeZoneSidKey, LocaleSidKey, LanguageLocaleKey, EmailEncodingKey FROM User WHERE Username = 'v413nc@gmail.com'];

List<User> existing = [SELECT Id FROM User WHERE Username = 'prontosupport2@pronto-ideathon.demo'];
User ops;
if (existing.isEmpty()) {
  ops = new User(FirstName = 'Pronto', LastName = 'Merchant Ops', Alias = 'pmops',
    Email = 'prontosupport2@gmail.com', Username = 'prontosupport2@pronto-ideathon.demo',
    CommunityNickname = 'prontomerchantops', ProfileId = adminProfile, UserPermissionsSupportUser = true,
    TimeZoneSidKey = valen.TimeZoneSidKey, LocaleSidKey = valen.LocaleSidKey,
    LanguageLocaleKey = valen.LanguageLocaleKey, EmailEncodingKey = valen.EmailEncodingKey);
  Database.DMLOptions dmo = new Database.DMLOptions();
  dmo.EmailHeader.triggerUserEmail = true; // sends the "set your password" email to prontosupport2@gmail.com
  Database.insert(ops, dmo);
} else {
  ops = new User(Id = existing[0].Id);
}

User ethan = [SELECT Id FROM User WHERE Username = 'ethanskinner216@gmail.com'];
ethan.ProfileId = adminProfile;
ethan.UserPermissionsSupportUser = true;
update ethan;

Id ps = [SELECT Id FROM PermissionSet WHERE Name = 'Pronto_Ideathon_Access'].Id;
List<PermissionSetAssignment> psas = new List<PermissionSetAssignment>();
List<GroupMember> gms = new List<GroupMember>();
List<Group> queues = [SELECT Id FROM Group WHERE Type = 'Queue' AND DeveloperName IN ('Merchant_Ops_Queue','Agent_Escalations_Queue')];
for (Id uid : new List<Id>{ ops.Id, ethan.Id }) {
  if ([SELECT COUNT() FROM PermissionSetAssignment WHERE AssigneeId = :uid AND PermissionSetId = :ps] == 0)
    psas.add(new PermissionSetAssignment(AssigneeId = uid, PermissionSetId = ps));
  for (Group q : queues)
    if ([SELECT COUNT() FROM GroupMember WHERE GroupId = :q.Id AND UserOrGroupId = :uid] == 0)
      gms.add(new GroupMember(GroupId = q.Id, UserOrGroupId = uid));
}
insert psas;
insert gms;
System.debug('ops user ' + ops.Id + ', ethan ' + ethan.Id + ', permsets ' + psas.size() + ', queue memberships ' + gms.size());
