import gql from 'graphql-tag';

// DO NOT CHANGE TO domainBySubdomainAndDomain(domain: $domain, subdomain: $subdomain)
// condition is the way to handle since it will pass in null properly
// e.g. subdomain.domain or domain both work
export const ApiQuery = gql`
  query ApiRoot($domain: String!, $subdomain: String) {
    domains(condition: { domain: $domain, subdomain: $subdomain }) {
      nodes {
        api {
          databaseId
          dbname
          roleName
          anonRole
          isPublic
          schemaNamesFromExt: apiExtensions {
            nodes {
              schemaName
            }
          }
          schemaNames: schemataByApiSchemaApiIdAndSchemaId {
            nodes {
              schemaName
            }
          }
          rlsModule {
            privateSchema {
              schemaName
            }
            authenticate
            currentRole
            currentRoleId
            currentGroupIds
          }
          # for now keep this for patches
          apiModules {
            nodes {
              name
              data
            }
          }
        }
      }
    }
  }
`;

// DO NOT CHANGE TO domainBySubdomainAndDomain(domain: $domain, subdomain: $subdomain)
// condition is the way to handle since it will pass in null properly
// e.g. subdomain.domain or domain both work
export const SiteQuery = gql`
  query Site($domain: String!, $subdomain: String) {
    domains(condition: { domain: $domain, subdomain: $subdomain }) {
      nodes {
        site {
          title
          description
          logo
          favicon
          ogImage
          appleTouchIcon
          app {
            name
            appImage
            appStoreLink
            playStoreLink
          }
          siteThemes {
            nodes {
              theme
            }
          }
          siteModules {
            nodes {
              name
              data
            }
          }
        }
      }
    }
  }
`;
