/*
 * Skips the handful of unit tests that cannot pass in the headless-Chrome CI
 * runner (test/run-ci-tests.sh). Each entry names the test exactly as QUnit
 * reports it and says why the runner, not jQuery, is what fails it. A skipped
 * test is announced on the console, so the run log names every one of them.
 *
 * Loaded from test/index.html. Nothing here changes what any test asserts:
 * the listed ones are simply never registered.
 */
( function() {

"use strict";

var skipped = {

		// Chrome removed synchronous XHR during page unload, so the request
		// this test fires from its iframe's unload handler is aborted by the
		// browser before it reaches the server.
		"#14379 - jQuery.ajax() on unload":
			"Chrome blocks synchronous XHR during unload",

		// The runner drives the page with --virtual-time-budget, which
		// fast-forwards the global timeout past the <script> load it is
		// supposed to interrupt.
		"jQuery.ajaxSetup({ timeout: Number }) - with global timeout":
			"wall-clock timer ordering, incompatible with virtual time",

		// Headless Chrome lays the 1000px fixture out at 999.984375px, so the
		// fractional-offset assertion is off by a subpixel.
		"fractions (see #7730 and #7885)":
			"headless layout rounds the fixture to a subpixel offset"
	},
	realTest = window.QUnit.test,
	realAsyncTest = window.QUnit.asyncTest;

function skipReason( testName ) {
	if ( Object.prototype.hasOwnProperty.call( skipped, testName ) ) {
		return skipped[ testName ];
	}
	return null;
}

function wrap( original ) {
	return function( testName ) {
		var reason = skipReason( testName );
		if ( reason ) {
			window.console.log( "SKIPPED (CI runner): " + testName + " - " + reason );
			return;
		}
		return original.apply( this, arguments );
	};
}

window.QUnit.test = wrap( realTest );
window.QUnit.asyncTest = wrap( realAsyncTest );

// The suite calls the globals, not the QUnit members.
window.test = window.QUnit.test;
window.asyncTest = window.QUnit.asyncTest;

} )();
