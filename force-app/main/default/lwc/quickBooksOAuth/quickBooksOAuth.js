import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// QuickBooks Auth
import getAccessToken from '@salesforce/apex/QuickBooksAuthController.getAccessToken';
import getQuickBookMetadata from '@salesforce/apex/QuickBooksAuthController.getQuickBookMetadata';
import updateQuickBookMetadata from '@salesforce/apex/QuickBooksAuthController.updateQuickBookMetadata';
import refreshAccessToken from '@salesforce/apex/QuickBooksAuthController.refreshAccessToken';

// QuickBooks Account Sync
import syncAccounts from '@salesforce/apex/QBOAccountSync.syncAccountsBidirectional';
import GetQBOUpdatedAccounts from '@salesforce/apex/QBOAccountSync.GetQBOUpdatedAccounts';

export default class QuickBooksOAuth extends LightningElement {

   @track authToken = '';
   @track refreshToken = '';
   @track authCode = '';
   @track realmId = '';
   @track metadata; // Stores the metadata record
   @track error;    // Stores error messages
   @track isLoading = false;

   async connectedCallback() {

      // Get URL parameters (code and realmId from the URL)
      const { code, realmId } = this.getCodeAndRealmId();
      this.realmId = realmId;

      // Get metadata to check if accessToken exists
      const result = await this.handleGetMetadata();

      const { accessToken = null, refreshToken = null } = result;

      this.accessToken = accessToken;
      this.refreshToken = refreshToken;

      if (!accessToken && !code && !realmId) {
         this.handleAuthRedirect();
      } else if (code && realmId && !accessToken) {

         const { accessToken, refreshToken } = await this.handleGetToken(code, realmId);

         // Update metadata with the new tokens
         await this.updateMetadata(code, realmId, accessToken, refreshToken);
      }

      this.isLoading = false
   }

   handleAuthRedirect() {

      const clientId = this.metadata.clientId;
      const redirectUri = 'https://focusteck2-dev-ed--c.develop.vf.force.com/apex/Quick_Book_Integration';
      const scopes = 'com.intuit.quickbooks.accounting';
      const state = 'randomStateValue';

      // Construct the QuickBooks authorization URL
      const authUrl = `https://appcenter.intuit.com/connect/oauth2?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&response_type=code&scope=${encodeURIComponent(scopes)}&state=${state}`;

      // Redirect the user to the QuickBooks authorization page
      window.location.href = authUrl;
   }

   async handleGetToken(code, realmId) {
      try {
         // Call Apex method to fetch access token using code and realmId
         const result = await getAccessToken({ code, realmId });

         if (result.hasOwnProperty('error')) {
            this.handleAuthRedirect();
            throw new Error(result.error);
         }

         if (!result.accessToken || !result.refreshToken) {
            throw new Error("Error: No access token or refresh token received");
         }

         const { accessToken, refreshToken } = result;
         return { accessToken, refreshToken };
      } catch (error) {
         console.error('Error fetching token: ', error.message);
      }
   }

   async handleGetMetadata() {
      // Get the metadata record to check for existing accessToken and refreshToken
      const result = await getQuickBookMetadata();
      this.metadata = result;
      return result;
   }

   getCodeAndRealmId() {
      // Extract code and realmId from the URL parameters
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get('code__c');  // Use 'code' as the query parameter
      const realmId = urlParams.get('realmId__c');  // Use 'realmId' as the query parameter
      return { code, realmId };
   }

   async updateMetadata(code, realmId, accessToken, refreshToken) {
      try {
         // Call Apex method to update metadata with the new values
         await updateQuickBookMetadata({
            code,
            realmId,
            accessToken,
            refreshToken
         });
         console.log("Metadata updated successfully");
      } catch (error) {
         console.error('Error updating metadata: ', error.message);
      }
   }

   async refreshAccessToken() {

      const result = await refreshAccessToken({
         clientId: this.metadata.clientId,
         clientSecret: this.metadata.clientSecret,
         refreshToken: this.refreshToken,
         redirectUri: this.metadata.redirectUri
      });

      if (result.hasOwnProperty('error')) {
         this.handleAuthRedirect();
         throw new Error(result.error);
      }

      this.accessToken = result.accessToken;
      this.refreshToken = result.refreshToken;
      this.updateMetadata(this.authCode, this.realmId, this.accessToken, this.refreshToken);
   }

   async handleSyncAccounts() {
      try {
         const response = await GetQBOUpdatedAccounts();
         this.handleSyncResponse([response]);
         const result = await syncAccounts({ data: response.Account });
         this.handleSyncResponse(result);
      } catch (error) {
         this.showToast('Error', 'Error syncing accounts: ' + error?.body?.message, 'error');
         console.error('Error syncing accounts: ', error);
      }
   }

   async handleSyncResponse(result) {
      if (result && result.some(res => res.statusCode === 401)) {
         this.showToast('Error', 'Token expired or unauthorized. Try Again', 'error');
         await this.refreshAccessToken();
         return;
      }
      else if (result && result.some(res => res.statusCode === 400)) {
         this.showToast('Warning', 'One or more accounts failed to sync due to duplicate Account Name', 'warning');
         return;
      }
      else if (result && result.some(res => res.statusCode === 200)) {
         this.showToast('Success', 'Accounts synced successfully.', 'success');
      } else if (result && result.some(res => res.statusCode === 500)) {
         this.showToast('Error', 'Something went wrong!', 'error');
         return;
      }
   }


   showToast(title, message, variant) {
      const evt = new ShowToastEvent({
         title: title,
         message: message,
         variant: variant,
      });
      this.dispatchEvent(evt);
   }

}
