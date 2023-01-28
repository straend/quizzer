# quizzer

A new Flutter project.

### database format
Collection name `quizzes` documents in `quizzes` are competition ID's.
Content in competitions should follow the following format:
```
cities:
    Helsinki:
        questions:
            - alternatives:
                - "10"
                - "7"
                - "5"
              answer: "7"
              question: "How many neighbouring cities"
            - alternatives: null
              answer: "Helsinki"
              question: "Name in finnish"
        tips:
          10: "No help for you"
           8: "Some more help"
current: null

responses:
    Will be filled by contestants

```