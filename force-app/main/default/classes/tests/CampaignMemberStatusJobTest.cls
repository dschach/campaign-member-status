/**
 * @description Test the daily campaign status job
 *
 * @author      Sercante LLC
 * @since       2022
 * @group       CampaignMemberStatusTests
 */
@isTest
private class CampaignMemberStatusJobTest {
	public static Boolean gotProtectedStatuses = false;
	public static Boolean executed = false;

	@isTest
	private static void shouldWork() {
		//arrange
		MockService mock = new MockService();
		CampaignMemberService.instance = mock;

		//act
		Test.startTest();
		System.schedule('testJob', '0 0 23 * * ?', new CampaignMemberStatusJob());
		Test.stopTest();

		//assert
		Assert.isTrue(gotProtectedStatuses);
		Assert.isTrue(executed);
	}

	private class MockService extends CampaignMemberService {
		public override Set<Id> getCampaignsNeedingToBeFixed() {
			//System.debug('called getCampaignsNeedingToBeFixed mock');
			CampaignMemberStatusJobTest.gotProtectedStatuses = true;
			return new Set<Id>();
		}

		public override void enforceProtectedStatusesForCampaigns(Set<Id> campaignIds) {
			//System.debug('called enforceProtectedStatusesForCampaigns mock');
			CampaignMemberStatusJobTest.executed = true;
		}
	}
}