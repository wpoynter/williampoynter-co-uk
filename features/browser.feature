Feature: Clean page load
  The home page loads in a browser without console errors, and none of the
  requests it makes to the host under test fail or go over plain HTTP.
  Other hosts (the CSS and script CDNs, the analytics script, and the
  production origin Hugo bakes into absolute asset URLs) are not counted:
  an outage there is not a regression of this deploy.

  Scenario: The home page loads cleanly in a browser
    When I open the home page and watch the browser console and network
    Then no console errors were logged
    And none of the site's own requests failed
    And nothing of the site's own was loaded over plain HTTP when the site is on HTTPS
