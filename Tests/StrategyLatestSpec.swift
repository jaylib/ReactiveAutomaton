//
//  StrategyLatestSpec.swift
//  ReactiveAutomaton
//
//  Created by Yasuhiro Inami on 2016-07-21.
//  Copyright © 2016 Yasuhiro Inami. All rights reserved.
//

import Result
import ReactiveSwift
import ReactiveAutomaton
import Quick
import Nimble

/// NextMapping tests with `strategy = .Latest`.
class NextMappingLatestSpec: QuickSpec
{
    override func spec()
    {
        typealias Automaton = ReactiveAutomaton.Automaton<AuthState, AuthInput>
        typealias NextMapping = Automaton.NextMapping

        let (signal, observer) = Signal<AuthInput, NoError>.pipe()
        var automaton: Automaton?
        var lastReply: Reply<AuthState, AuthInput>?

        describe("strategy = `.Latest`") {

            var testScheduler: TestScheduler!

            beforeEach {
                testScheduler = TestScheduler()

                /// Sends `.LoginOK` after delay, simulating async work during `.LoggingIn`.
                let loginOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LoginOK)
                        .delay(1, on: testScheduler)

                /// Sends `.LogoutOK` after delay, simulating async work during `.LoggingOut`.
                let logoutOKProducer =
                    SignalProducer<AuthInput, NoError>(value: .LogoutOK)
                        .delay(1, on: testScheduler)

                let mappings: [Automaton.NextMapping] = [
                    .Login    | .LoggedOut  => .LoggingIn  | loginOKProducer,
                    .LoginOK  | .LoggingIn  => .LoggedIn   | .empty,
                    .Logout   | .LoggedIn   => .LoggingOut | logoutOKProducer,
                    .LogoutOK | .LoggingOut => .LoggedOut  | .empty,
                ]

                // strategy = `.latest`
                automaton = Automaton(state: .LoggedOut, input: signal, mapping: reduce(mappings), strategy: .latest)

                automaton?.replies.observeValues { reply in
                    lastReply = reply
                }

                lastReply = nil
            }

            it("`strategy = .Latest` should not interrupt inner next-producers when transition fails") {
                expect(automaton?.state.value) == .LoggedOut
                expect(lastReply).to(beNil())

                observer.sendNext(.Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggedOut
                expect(lastReply?.toState) == .LoggingIn
                expect(automaton?.state.value) == .LoggingIn

                testScheduler.advance(by: 0.1)

                // fails (`loginOKProducer` will not be interrupted)
                observer.sendNext(.Login)

                expect(lastReply?.input) == .Login
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState).to(beNil())
                expect(automaton?.state.value) == .LoggingIn

                // `loginOKProducer` will automatically send `.LoginOK`
                testScheduler.advance(by: 1)

                expect(lastReply?.input) == .LoginOK
                expect(lastReply?.fromState) == .LoggingIn
                expect(lastReply?.toState) == .LoggedIn
                expect(automaton?.state.value) == .LoggedIn
            }

        }

    }
}
