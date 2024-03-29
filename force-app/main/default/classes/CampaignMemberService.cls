/**
 * @description Some reusable logic for this solution
 * <br>(singleton pattern)
 *
 * @author      Sercante LLC
 * @since       2022
 * @group       CampaignMemberStatus
 */
public virtual without sharing class CampaignMemberService {
	@TestVisible
	private static CampaignMemberService instance;

	@TestVisible
	private CampaignMemberRepository repo;

	/**
	 * @description Running getInstance in a static context instantiates this class and its repo
	 * @see CampaignMemberService.repo
	 *
	 * @return      `CampaignMemberService`
	 */
	public static CampaignMemberService getInstance() {
		if (instance == null) {
			//System.debug('creating new instance of CampaignMemberService');
			instance = new CampaignMemberService();
			instance.repo = new CampaignMemberRepository();
		}
		return instance;
	}

	/**
	 * @description       Given a set of Campaign IDs, query the member status records for those Campaigns
	 *
	 * @param campaignIds Query `Campaign` records with child `CampaignMemberStatus` records
	 * @return            `List<Campaign>` `Campaign` records with child `CampaignMemberStatus` records
	 */
	public List<Campaign> getCampaignsWithMemberStatuses(Set<Id> campaignIds) {
		//System.debug('Start getCampaignsWithMemberStatuses');
		return [
			SELECT
				ID,
				Name,
				Type,
				(
					SELECT Id, Label, CampaignId, HasResponded, IsDefault, SortOrder
					FROM CampaignMemberStatuses
					ORDER BY IsDefault DESC
				)
			FROM Campaign
			WHERE Id IN :campaignIds AND Protect_Campaign_Member_Statuses__c = TRUE
		];
	}

	/**
	 * @description Get the CM Statuses for each Type
	 *
	 * @return      `Map<String, List<Campaign_Type_Member_Status__mdt>>`
	 */
	public virtual Map<String, List<Campaign_Type_Member_Status__mdt>> getGroupedProtectedStatuses() {
		return repo.getGroupedProtectedStatuses();
	}

	/**
	 * @description TODO: This method needs to be fixed to remove query from loop
	 *
	 * @return      `Set<Id>` Campaigns with statues not matching Protected count
	 */
	@SuppressWarnings('PMD')
	public virtual Set<Id> getCampaignsNeedingToBeFixed() {
		//System.debug('looking for Campaigns that might need to be fixed');
		Set<Id> campaignIdsNeedingFixes = new Set<Id>();
		Map<String, List<Campaign_Type_Member_Status__mdt>> protectedStatuses = repo.getGroupedProtectedStatuses();

		for (String type : protectedStatuses.keySet()) {
			//System.debug('Checking campaigns of type ' + type);
			List<String> expectedLabels = new List<String>();
			for (Campaign_Type_Member_Status__mdt expectedStatus : protectedStatuses.get(type)) {
				expectedLabels.add(expectedStatus.Campaign_Member_Status__c);
			}

			//System.debug('expecting ' + expectedLabels.size() + ' specific Statuses');
			List<AggregateResult> groupedResults = [
				SELECT CampaignId, Count(Id)
				FROM CampaignMemberStatus
				WHERE
					CampaignId IN (
						SELECT Id
						FROM Campaign
						WHERE Protect_Campaign_Member_Statuses__c = TRUE AND Type = :type AND IsActive = TRUE
					)
					AND Label IN :expectedLabels
				GROUP BY CampaignId
				HAVING Count(Id) != :expectedLabels.size()
			];

			for (AggregateResult ar : groupedResults) {
				campaignIdsNeedingFixes.add((Id) ar.get('CampaignId'));
			}
		}
		//System.debug('found ' + campaignIdsNeedingFixes.size() + ' Campaigns that are missing at least 1 of the mandatory Statuses');
		return campaignIdsNeedingFixes;
	}

	/**
	 * @description       Insert/Update CM Status records as needed
	 *
	 * @param campaignIds Campaigns to check
	 */
	public virtual void enforceProtectedStatusesForCampaigns(Set<Id> campaignIds) {
		//System.debug('Start enforceProtectedStatusesForCampaigns');
		List<Campaign> existingCampaigns = getCampaignsWithMemberStatuses(campaignIds);

		//if (campaignIds.size() != existingCampaigns.size()) {
		//	System.debug('There are some Campaigns that are not protected, ignoring those');
		//}
		if (existingCampaigns.isEmpty()) {
			//System.debug('There are no Campaigns to process');
			return;
		}

		Map<String, List<Campaign_Type_Member_Status__mdt>> protectedStatuses = repo.getGroupedProtectedStatuses();
		Map<Id, CampaignMemberStatus> toUpdate = new Map<Id, CampaignMemberStatus>();
		List<CampaignMemberStatus> toInsert = new List<CampaignMemberStatus>();

		for (Campaign camp : existingCampaigns) {
			//System.debug('Processing Campaign: ' + camp.Name);
			Boolean changeNeeded = false;
			List<CampaignMemberStatus> existingStatuses = camp.CampaignMemberStatuses;
			Map<String, CampaignMemberStatus> statusesByLabel = new Map<String, CampaignMemberStatus>();
			Integer sortOrder = 0;
			for (CampaignMemberStatus status : existingStatuses) {
				statusesByLabel.put(status.Label, status);
				if (status.SortOrder > sortOrder) {
					sortOrder = status.SortOrder;
				}
			}

			for (Campaign_Type_Member_Status__mdt expected : protectedStatuses.get(camp.Type)) {
				String expectedStatus = expected.Campaign_Member_Status__c;
				if (statusesByLabel.containsKey(expectedStatus)) {
					//System.debug('Status of ' + expectedStatus + ' is already there. Checking to see if it has the right checkboxes');
					CampaignMemberStatus realStatus = statusesByLabel.get(expectedStatus);
					if (realStatus.IsDefault != expected.IsDefault__c) {
						//System.debug('the Default checkbox was not as expected. Setting it now');
						changeNeeded = true;
						realStatus.IsDefault = expected.IsDefault__c;
						toUpdate.put(realStatus.Id, realStatus);
					}
					if (realStatus.HasResponded != expected.HasResponded__c) {
						//System.debug('the Responded checkbox was not as expected. Setting it now');
						changeNeeded = true;
						realStatus.HasResponded = expected.HasResponded__c;
						toUpdate.put(realStatus.Id, realStatus);
					}
				} else {
					//System.debug('We detected that Status: ' + expectedStatus + ' is missing');
					sortOrder++;
					CampaignMemberStatus newStatus = new CampaignMemberStatus(
						CampaignId = camp.Id,
						Label = expected.Campaign_Member_Status__c,
						HasResponded = expected.HasResponded__c,
						SortOrder = sortOrder
					);

					changeNeeded = true;
					//System.debug(newStatus);
					toInsert.add(newStatus);
				}
			}
			//if (!changeNeeded) {
			//System.debug('This camp looks good! No changes needed');
			//}
		}

		if (!toUpdate.isEmpty()) {
			//System.debug('We are updating ' + toUpdate.size() + ' Status records');
			update toUpdate.values();
		}
		if (!toInsert.isEmpty()) {
			//System.debug('We are inserting ' + toInsert.size() + ' Status records');
			insert toInsert;
		}
	}
}