// MSAL configuration for Microsoft Entra External ID (CIAM)
import type { Configuration } from '@azure/msal-browser';

export const msalConfig: Configuration = {
  auth: {
    clientId: 'cf6cfea3-fca3-4e29-94fa-bd7287c144b7', // Application (client) ID
    authority: 'https://login.microsoftonline.com/96e7dd96-48b5-4991-a67e-1563013dfbe2', // Directory (tenant) ID
    redirectUri: 'https://nice-wave-0f76af61e.1.azurestaticapps.net', // Azure Static Web App URL
  },
  cache: {
    cacheLocation: 'sessionStorage',
    storeAuthStateInCookie: false,
  },
}; 