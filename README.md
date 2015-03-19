# ProjectOmeletteManager
[![Build Status](https://semaphoreci.com/api/v1/projects/5335bd3a-765e-4fd6-8521-402e2be6a680/372989/badge.png)](https://semaphoreci.com/perceptive/cloudos_manager)      

To start your new Phoenix application:

1. Install dependencies with `mix deps.get`
2. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

## Module Configuration

The following configuration values must be defined either as environment variables or as part of the environment configuration files:

* Messaging Private Key
	* Type:  String
	* Description:  The absolute location of the private key for encrypting passwords
  * Environment Variable:  CLOUDOS_MANAGER_MESSAGING_PRIVATE_KEY
* Messaging Public Key
	* Type:  String
	* Description:  The absolute location of the public key for encrypting passwords
  * Environment Variable:  CLOUDOS_MANAGER_MESSAGING_PUBLIC_KEY
* Messaging Key Name
	* Type:  String
	* Description:  An identifier that can be used for the password encryption keyfile
  * Environment Variable:  CLOUDOS_MANAGER_MESSAGING_KEYNAME

The MessagingBrokersController tests require a keyfile to be present in order for the tests to pass and functionality to work.  A quick way to generate the required PEMs is as follows:

```
ssh-keygen -t rsa -b 1024 -C "Test Key"
openssl rsa -in testing.pem -pubout
```