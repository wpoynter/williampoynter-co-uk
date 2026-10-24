Feature: Navigation
  The side navigation carries one link per homepage section that
  config.toml turns on, and every internal link on the home page leads
  somewhere that exists. The theme has no footer navigation.

  Scenario: The header offers a link to every section that is turned on
    When I open the home page
    Then the header navigation lists the sections config.toml turns on
    And every header navigation link resolves

  Scenario: Every internal link on the home page resolves
    When I open the home page
    Then every internal link on the page resolves
