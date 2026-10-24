Feature: Routing
  Clean URLs end in a slash, and a URL without one redirects to the page on
  the same public origin. Unknown addresses answer 404 with the site's own
  not-found page.

  @origin
  Scenario: A section URL without its trailing slash redirects on the same origin
    Then every section page requested without its trailing slash redirects on this origin to the page

  Scenario: An unknown address shows the not-found page
    When I open "/this-page-does-not-exist/"
    Then the page answers 404
    And the page has exactly one main heading
    And the page title starts with the site title
    And the page links back to the home page
