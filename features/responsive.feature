Feature: Phone layout
  On a phone the side navigation collapses behind a menu button that opens
  the same links and still takes the visitor to the section.

  Scenario: The navigation works on a phone
    Given a phone-sized viewport
    When I open the home page
    Then the menu button is shown and the navigation is hidden
    When I press the menu button
    Then the navigation is shown with the sections config.toml turns on
    When I follow the last navigation link
    Then the menu closes and that section is in view
