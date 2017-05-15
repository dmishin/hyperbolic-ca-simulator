.PHONY = test test_app start startwin publish

application:
	browserify -t coffeeify src/ui/application.coffee > application.js
#	browserify -t coffeeify src/ui/render_worker.coffee > render_worker.js

test:
	mocha tests/test*.coffee --compilers coffee:coffee-script/register

start:
	python http_server_with_upload.py &
	xdg-open http://localhost:8000/index.html

startwin:
	/c/Python33/python.exe http_server_with_upload.py &
	start http://localhost:8000/index.html

clean:
	rm application.js render_worker.js


publish: test application
	git checkout master
	sh publish.sh
	cd ../homepage-sources && sh ./publish.sh
