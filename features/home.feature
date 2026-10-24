Feature: Home page
  The home page is the resume itself: one main heading, the site title,
  and the description from config.toml, which proves the real Hugo site
  rendered rather than an nginx default page or the near-blank page a
  build without the theme submodule produces.

  # Moved from ci/verify-staging.sh (curl / = 200, and curl / | grep
  # "William Poynter", which lives in the config.toml description): the
  # real site, with its config, is what answers at the root.
  Scenario: The home page renders
    When I open the home page
    Then the page answers 200
    And the page has exactly one main heading
    And the page title is the site title and the home page's title
    And the page carries the site description from config.toml
