# Changelog

All notable changes to this project will be documented in this file.

## [1.0.2]
- Redis-namespace dependency now requires version 1.8.2 or more recent, because thread safety was broken in 1.8.1
- Adds processing for case when `watch` fails in redis transactions (during unlocking).

## [1.0.1]

- Bugfix with active job/batches memoization in `SimpleMutex::SidekiqSupport::JobCleaner` and
`SimpleMutex:SidekiqSupport::BatchCleaner`
- Simplecov added
- More tests added for 100% coverage

## [1.0.0]

Initial public release