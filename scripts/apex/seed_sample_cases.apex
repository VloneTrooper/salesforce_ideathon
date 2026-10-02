// Phase 3 sample data. Every record is tagged "[Sample data]" in Description.
// Delete with: delete [SELECT Id FROM Case WHERE Description LIKE '[Sample data]%'];
// Merchant reports are seeded Closed (so the live "out of fries" bonus demo is not triggered by fake data).
// Agent failures are inserted with Origin 'Web' then updated to 'Agent', so the alert flow (on create) does not fire.
Map<String, Id> sf = new Map<String, Id>();
for (Storefront__c s : [SELECT Id, Name FROM Storefront__c]) sf.put(s.Name, s.Id);
Map<String, Id> q = new Map<String, Id>();
for (Group g : [SELECT Id, DeveloperName FROM Group WHERE Type = 'Queue' AND DeveloperName IN ('Merchant_Ops_Queue','Agent_Escalations_Queue')]) q.put(g.DeveloperName, g.Id);
Id lead = [SELECT Id FROM User WHERE Username = 'v413nc@gmail.com'].Id;
String TAG = '[Sample data] ';

// storefront => {customer missing, late, wrong, cold, merchant outOfStock, prepDelay, handoff}
Map<String, List<Integer>> plan = new Map<String, List<Integer>>{
  'Urban Table Downtown'        => new List<Integer>{6, 2, 2, 1, 0, 0, 1},
  'Urban Table Uptown'          => new List<Integer>{2, 1, 1, 0, 1, 1, 0},
  'Fusion Bites Oak Lawn'       => new List<Integer>{1, 4, 0, 1, 1, 3, 0},
  'Fusion Bites'                => new List<Integer>{1, 1, 1, 0, 1, 0, 1},
  'The Savory Spot Bishop Arts' => new List<Integer>{3, 1, 2, 0, 0, 0, 0},
  'Munch Central Trinity Groves'=> new List<Integer>{1, 2, 0, 1, 2, 1, 1},
  'Harvest Grill'               => new List<Integer>{1, 0, 1, 1, 1, 0, 0},
  'Artisan’s Edge Uptown'       => new List<Integer>{2, 1, 0, 0, 0, 1, 1}
};
List<String> custReasons = new List<String>{'Missing items','Order running late','Wrong items delivered','Order arrived cold'};
List<String> custSubj = new List<String>{'Items missing from my order','My order is really late','I got the wrong order','Food arrived cold'};
List<String> merReasons = new List<String>{'Out of Stock','Prep Delay','Handoff Issue'};
List<String> merSubj = new List<String>{'Out of fries tonight','Kitchen running 20 min late','Courier left without drinks bag'};
List<String> custOrigins = new List<String>{'Pronto App','Web'};

List<Case> cases = new List<Case>();
Integer n = 0;
for (String name : plan.keySet()) {
  List<Integer> p = plan.get(name);
  for (Integer r = 0; r < 4; r++) for (Integer i = 0; i < p[r]; i++) {
    n++;
    Boolean open = Math.mod(n, 3) == 0;
    cases.add(new Case(Storefront__c = sf.get(name), Origin = custOrigins[Math.mod(n, 2)], Type = 'Customer Order Issue',
      Reason = custReasons[r], Subject = custSubj[r] + ' (' + name + ')', Status = open ? 'New' : 'Closed',
      Priority = r == 0 ? 'High' : 'Medium', OwnerId = lead, Description = TAG + 'Customer-reported order issue.'));
  }
  for (Integer r = 0; r < 3; r++) for (Integer i = 0; i < p[4 + r]; i++) {
    cases.add(new Case(Storefront__c = sf.get(name), Origin = 'Merchant Report', Type = 'Merchant Operations',
      Reason = merReasons[r], Subject = merSubj[r], Status = 'Closed', Priority = 'Medium',
      OwnerId = lead, Description = TAG + 'Merchant/courier email report.'));
  }
}
// A few open merchant reports for the "open cases by queue" chart (not Urban Table Downtown; not today's demo).
cases.add(new Case(Storefront__c = sf.get('Fusion Bites Oak Lawn'), Origin = 'Merchant Report', Type = 'Merchant Operations', Reason = 'Prep Delay', Subject = 'Short-staffed in kitchen, running late', Status = 'New', Priority = 'Medium', OwnerId = q.get('Merchant_Ops_Queue'), Description = TAG + 'Merchant/courier email report.'));
cases.add(new Case(Storefront__c = sf.get('Munch Central Trinity Groves'), Origin = 'Merchant Report', Type = 'Merchant Operations', Reason = 'Handoff Issue', Subject = 'Courier picked up wrong bag', Status = 'New', Priority = 'Medium', OwnerId = q.get('Merchant_Ops_Queue'), Description = TAG + 'Merchant/courier email report.'));
insert cases;

// Agent failures: insert as Web, then flip to Agent (alert flow only fires on create).
List<String> ft = new List<String>{'Clarification Loop','Clarification Loop','Clarification Loop','Clarification Loop','Clarification Loop','Clarification Loop','Action Error','Action Error','Action Error','Escalation Failed','Escalation Failed'};
List<Case> agentCases = new List<Case>();
for (Integer i = 0; i < ft.size(); i++) {
  Boolean open = i < 3;
  agentCases.add(new Case(Origin = 'Web', Subject = 'Agent failure: ' + ft[i], Failure_Type__c = ft[i],
    Priority = ft[i] == 'Clarification Loop' ? 'Medium' : 'High', Status = open ? 'New' : 'Closed',
    OwnerId = open ? q.get('Agent_Escalations_Queue') : lead, Description = TAG + 'Agent could not resolve the conversation.'));
}
insert agentCases;
for (Case c : agentCases) c.Origin = 'Agent';
update agentCases;
System.debug('Seeded ' + cases.size() + ' storefront cases and ' + agentCases.size() + ' agent failure cases');
