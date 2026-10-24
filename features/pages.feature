Feature: Every published page renders
  Each section (list) page and each published publication, project or
  standalone page answers 200 with a heading and the title Hugo gives it.
  The lists come from content/ (drafts, future-dated and expired pages
  left out, as Hugo does), so a new page is covered without editing this
  file.

  Scenario: Every section page renders
    Then every section page from the content renders with a heading and a title

  Scenario: Every published content page renders
    Then every published content page renders with a heading and a title
