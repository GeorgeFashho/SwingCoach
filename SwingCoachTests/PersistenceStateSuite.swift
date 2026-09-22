//
//  PersistenceStateSuite.swift
//  SwingCoachTests
//

import Testing

/// Parent suite for every test that mutates the process-global UserDefaults keys
/// `progressBaselineDate` / `previousFocusArea`. `.serialized` on the PARENT serializes
/// across all nested suites — per-suite `.serialized` does not, so different suites would
/// otherwise run in parallel and race on the shared keys.
@Suite(.serialized) struct PersistenceStateSuite {}
