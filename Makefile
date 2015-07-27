.PHONY = test test_app

test_app:
	browserify -t coffeeify hyperbolic_tessellation_test_app.coffee > test_app_bundle.js
	browserify -t coffeeify render_worker.coffee > render_worker.js

test:
	mocha test*.coffee --compilers coffee:coffee-script/register

