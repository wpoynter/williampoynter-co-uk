Feature: Health and build identity
  The nginx image answers a cheap health check for the kubelet probes and
  the promote verdict, and names the build it is serving so CI can tell
  which image a host runs.

  # Moved from ci/verify-staging.sh (curl /healthz = 200): ci/promote.sh
  # judges staging by this endpoint at promote time, so it must answer.
  @origin
  Scenario: The health endpoint answers
    When I request "/healthz"
    Then the response status is 200
    And the response body is "ok"

  @origin
  Scenario: The build tag names the running build
    When I request "/build-tag.txt"
    Then the response status is 200
    And the response is served as "text/plain"
    And the response body is a single build tag
    And the build tag matches the one CI expects, if any
