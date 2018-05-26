get::
	pub get
	go get .

serve:
	go run exampleserver.go --enable_tls

test:
	TEST_HTTPS=true pub run test

