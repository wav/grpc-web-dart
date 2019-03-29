get::
	pub get
	go get .

serve:
	[[ ! -f cert.pem ]] && openssl req -x509 -newkey rsa:4096 -nodes -keyout key.pem -out cert.pem -days 1 -subj '/CN=localhost' || true
	go run exampleserver.go --enable_tls

.PHONY: test
test:
	TEST_HTTPS=true pub run test
