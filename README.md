# Manager

[![Build Status](https://semaphoreci.com/api/v1/projects/57ae4ce0-e5f1-4a08-ab29-715b56d03480/398198/badge.svg)](https://semaphoreci.com/perceptive/manager)
 
To start your new Phoenix application:

1. Install dependencies with `mix deps.get`
2. Start Phoenix endpoint with `mix phoenix.server`

Now you can visit `localhost:4000` from your browser.

## Contributing

To contribute to OpenAperture development, view our [contributing guide](http://openaperture.io/dev_resources/contributing.html)

## Module Configuration

The following configuration values must be defined either as environment variables or as part of the environment configuration files:

* Messaging Private Key
	* Type:  String
	* Description:  The absolute location of the private key for encrypting passwords
  * Environment Variable:  MANAGER_MESSAGING_PRIVATE_KEY
* Messaging Public Key
	* Type:  String
	* Description:  The absolute location of the public key for encrypting passwords
  * Environment Variable:  MANAGER_MESSAGING_PUBLIC_KEY
* Messaging Key Name
	* Type:  String
	* Description:  An identifier that can be used for the password encryption keyfile
  * Environment Variable:  MANAGER_MESSAGING_KEYNAME
* Current Exchange
	* Type:  String
	* Description:  The identifier of the exchange in which the Orchestrator is running
  * Environment Variable:  EXCHANGE_ID
* Current Broker
	* Type:  String
	* Description:  The identifier of the broker to which the Orchestrator is connecting
  * Environment Variable:  BROKER_ID
* Manager URL
  * Type: String
  * Description: The url of the OpenAperture Manager
  * Environment Variable:  MANAGER_URL
  * Environment Configuration (.exs): :openaperture_manager_api, :manager_url
* OAuth Login URL
  * Type: String
  * Description: The login url of the OAuth2 server
  * Environment Variable:  OAUTH_LOGIN_URL
  * Environment Configuration (.exs): :openaperture_manager_api, :oauth_login_url
* OAuth Client ID
  * Type: String
  * Description: The OAuth2 client id to be used for authenticating with the OpenAperture Manager
  * Environment Variable:  OAUTH_CLIENT_ID
  * Environment Configuration (.exs): :openaperture_manager_api, :oauth_client_id
* OAuth Client Secret
  * Type: String
  * Description: The OAuth2 client secret to be used for authenticating with the OpenAperture Manager
  * Environment Variable:  OAUTH_CLIENT_SECRET
  * Environment Configuration (.exs): :openaperture_manager_api, :oauth_client_secret
* System Module Type
  * Type:  atom or string
  * Description:  An atom or string describing what kind of system module is running (i.e. builder, deployer, etc...)
  * Environment Configuration (.exs): :openaperture_overseer_api, :module_type
  
The MessagingBrokers (Controller) tests require a keyfile to be present in order for the tests to pass and functionality to work.  A quick way to generate the required PEMs is as follows:

```
ssh-keygen -t rsa -b 1024 -C "Test Key"
openssl rsa -in testing.pem -pubout
```
