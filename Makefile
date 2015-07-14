
test:
	mocha test*.coffee --compilers coffee:coffee-script/register

test_app:
	browserify -t coffeeify hyperbolic_tessellation_test_app.coffee > test_app_bundle.js

.PHONY = test test_app
