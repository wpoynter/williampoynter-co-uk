Feature: Sitemap and robots.txt
  The sitemap lists every published page and nothing it lists is broken.
  robots.txt points search engines at it.

  # Moved from ci/verify-staging.sh (curl sitemap.xml | grep "<urlset"):
  # Hugo writes the sitemap on every build, so a missing or empty one means
  # the build or the image is wrong, not the content.
  Scenario: The sitemap is served
    When I request "/sitemap.xml"
    Then the response status is 200
    And the response is XML
    And the response body contains "<urlset"

  Scenario: The sitemap lists every published page
    Then the sitemap lists the home page, every section page and every published content page

  Scenario: Every sitemap URL answers
    Then every page in the sitemap answers 200 on this host

  Scenario: robots.txt points at the sitemap
    When I request "/robots.txt"
    Then the response status is 200
    And the response is served as "text/plain"
    And the response body has a line starting "Sitemap: "
