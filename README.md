# ProjectOmeletteManager
[![Build Status](https://semaphoreci.com/api/v1/projects/5335bd3a-765e-4fd6-8521-402e2be6a680/372989/badge.png)](https://semaphoreci.com/perceptive/cloudos_manager)      

To start your new Phoenix application:

1. Install dependencies with `mix deps.get`
2. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

The MessagingBrokersController tests require a keyfile to be present in order for the tests to pass and functionality to work.  A quick way to generate the required PEMs is as follows:

```
ssh-keygen -t rsa -b 1024 -C "Test Key"
openssl rsa -in testing.pem -pubout
```